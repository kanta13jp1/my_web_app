#!/usr/bin/env python3
"""Small offline-only RAG runtime harness for local validation.

The harness intentionally uses only the Python standard library. It can run as a
one-shot validator or as a localhost HTTP endpoint consumed by the Flutter app.
For real model execution, start this process beside llama.cpp/Ollama/LocalAI and
replace the extractive answer builder with a local generator command.
"""

from __future__ import annotations

import argparse
import contextlib
import json
import re
import socket
import sys
import textwrap
import time
import tracemalloc
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


TEXT_EXTENSIONS = {".txt", ".md", ".markdown", ".json", ".jsonl"}
TOKEN_RE = re.compile(r"[A-Za-z0-9_\u3040-\u30ff\u3400-\u9fff]{2,}")


@dataclass(frozen=True)
class Document:
    source_id: str
    title: str
    path: str
    text: str


@contextlib.contextmanager
def block_external_network() -> Any:
    original_connect = socket.socket.connect

    def guarded_connect(self: socket.socket, address: Any) -> Any:
        host = address[0] if isinstance(address, tuple) and address else ""
        if host not in {"127.0.0.1", "::1", "localhost"}:
            raise OSError("external network is blocked for local RAG validation")
        return original_connect(self, address)

    socket.socket.connect = guarded_connect  # type: ignore[method-assign]
    try:
        yield
    finally:
        socket.socket.connect = original_connect  # type: ignore[method-assign]


def tokenize(text: str) -> set[str]:
    return {item.lower() for item in TOKEN_RE.findall(text)}


def read_json_text(path: Path) -> str:
    data = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(data, str):
        return data
    if isinstance(data, dict):
        parts = []
        for key in ("title", "body", "text", "content", "summary"):
            value = data.get(key)
            if isinstance(value, str):
                parts.append(value)
        return "\n".join(parts)
    if isinstance(data, list):
        return "\n".join(str(item) for item in data)
    return str(data)


def read_jsonl_text(path: Path) -> str:
    parts: list[str] = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip():
            continue
        try:
            data = json.loads(line)
        except json.JSONDecodeError:
            parts.append(line)
            continue
        if isinstance(data, dict):
            value = data.get("text") or data.get("content") or data.get("body")
            parts.append(str(value if value is not None else data))
        else:
            parts.append(str(data))
    return "\n".join(parts)


def load_documents(vector_db_path: str) -> list[Document]:
    source = Path(vector_db_path).expanduser()
    if not source.exists():
        raise FileNotFoundError(f"vector DB path not found: {source}")

    files = [source] if source.is_file() else [
        item for item in sorted(source.rglob("*"))
        if item.is_file() and item.suffix.lower() in TEXT_EXTENSIONS
    ]
    documents: list[Document] = []
    for index, path in enumerate(files, start=1):
        try:
            suffix = path.suffix.lower()
            if suffix == ".json":
                text = read_json_text(path)
            elif suffix == ".jsonl":
                text = read_jsonl_text(path)
            else:
                text = path.read_text(encoding="utf-8", errors="ignore")
        except Exception as exc:
            text = f"Skipped unreadable document: {exc}"
        text = text.lstrip("\ufeff")
        if text.strip():
            documents.append(
                Document(
                    source_id=f"doc-{index}",
                    title=path.stem,
                    path=str(path),
                    text=text.strip(),
                )
            )
    if not documents:
        raise ValueError(f"no readable documents under vector DB path: {source}")
    return documents


def rank_documents(query: str, documents: list[Document]) -> list[tuple[float, Document]]:
    query_tokens = tokenize(query)
    ranked: list[tuple[float, Document]] = []
    for doc in documents:
        doc_tokens = tokenize(doc.text)
        overlap = query_tokens & doc_tokens
        count_hits = sum(doc.text.lower().count(token) for token in query_tokens)
        score = (len(overlap) * 2.0 + count_hits * 0.35) / max(1, len(query_tokens))
        if score > 0:
            ranked.append((round(score, 4), doc))
    if not ranked:
        ranked = [(0.01, doc) for doc in documents[:3]]
    ranked.sort(key=lambda item: item[0], reverse=True)
    return ranked[:5]


def snippet_for(query: str, text: str, limit: int = 260) -> str:
    sentences = re.split(r"(?<=[.!?\u3002\uff01\uff1f])\s+", text)
    query_tokens = tokenize(query)
    best = max(
        sentences or [text],
        key=lambda sentence: len(tokenize(sentence) & query_tokens),
    )
    return textwrap.shorten(best.strip().replace("\n", " "), width=limit)


def answer_from_citations(query: str, ranked: list[tuple[float, Document]]) -> str:
    parts = [snippet_for(query, doc.text, limit=180) for _, doc in ranked[:3]]
    joined = " ".join(part for part in parts if part)
    return textwrap.shorten(
        f"{joined}\n\nSources: " + ", ".join(doc.title for _, doc in ranked[:3]),
        width=1200,
    )


def run_rag(
    *,
    query: str,
    model_path: str,
    vector_db_path: str,
    engine: str,
    memory_limit_mb: int,
    network_blocked: bool,
) -> dict[str, Any]:
    started = time.perf_counter()
    model = Path(model_path).expanduser()
    if not model.exists():
        return {
            "success": False,
            "status": "missingModel",
            "message": f"local model path not found: {model}",
            "offline_only": True,
            "network_blocked": network_blocked,
        }

    tracemalloc.start()
    documents = load_documents(vector_db_path)
    ranked = rank_documents(query, documents)
    current_bytes, peak_bytes = tracemalloc.get_traced_memory()
    del current_bytes
    memory_peak_mb = int((peak_bytes / 1024 / 1024) + 0.999)
    tracemalloc.stop()

    if memory_peak_mb > memory_limit_mb:
        return {
            "success": False,
            "status": "memoryLimitExceeded",
            "message": f"peak {memory_peak_mb} MB exceeds {memory_limit_mb} MB",
            "memory_peak_mb": memory_peak_mb,
            "offline_only": True,
            "network_blocked": network_blocked,
        }

    citations = [
        {
            "source_id": doc.source_id,
            "title": doc.title,
            "path": doc.path,
            "snippet": snippet_for(query, doc.text),
            "score": score,
        }
        for score, doc in ranked
    ]
    return {
        "success": True,
        "status": "ok",
        "text": answer_from_citations(query, ranked),
        "engine": engine,
        "model": model.name,
        "model_path": str(model),
        "vector_db_path": str(Path(vector_db_path).expanduser()),
        "offline_only": True,
        "network_blocked": network_blocked,
        "memory_peak_mb": memory_peak_mb,
        "latency_ms": int((time.perf_counter() - started) * 1000),
        "citations": citations,
    }


class RagHandler(BaseHTTPRequestHandler):
    config: argparse.Namespace

    def do_OPTIONS(self) -> None:
        self._send_json({"success": True})

    def do_POST(self) -> None:
        if self.path.rstrip("/") != "/rag":
            self._send_json({"success": False, "message": "not found"}, status=404)
            return
        length = int(self.headers.get("content-length") or "0")
        payload = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
        result = run_rag(
            query=str(payload.get("query") or payload.get("prompt") or ""),
            model_path=str(payload.get("model_path") or self.config.model_path),
            vector_db_path=str(payload.get("vector_db_path") or self.config.vector_db_path),
            engine=str(payload.get("engine") or self.config.engine),
            memory_limit_mb=int(payload.get("memory_limit_mb") or self.config.memory_limit_mb),
            network_blocked=self.config.enforce_network_block,
        )
        self._send_json(result, status=200 if result.get("success") else 409)

    def log_message(self, format: str, *args: Any) -> None:
        if not self.config.quiet:
            super().log_message(format, *args)

    def _send_json(self, body: dict[str, Any], status: int = 200) -> None:
        encoded = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("content-type", "application/json; charset=utf-8")
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-headers", "content-type")
        self.send_header("content-length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--query", default="")
    parser.add_argument("--model-path", required=True)
    parser.add_argument("--vector-db-path", required=True)
    parser.add_argument("--engine", default="pleias-rag")
    parser.add_argument("--memory-limit-mb", type=int, default=8192)
    parser.add_argument("--enforce-network-block", action="store_true")
    parser.add_argument("--serve", action="store_true")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--quiet", action="store_true")
    return parser.parse_args(argv)


def emit_json(body: dict[str, Any]) -> None:
    encoded = json.dumps(body, ensure_ascii=False, indent=2).encode("utf-8")
    sys.stdout.buffer.write(encoded + b"\n")


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    guard = block_external_network() if args.enforce_network_block else contextlib.nullcontext()
    with guard:
        if args.serve:
            RagHandler.config = args
            server = ThreadingHTTPServer((args.host, args.port), RagHandler)
            print(f"local RAG runtime listening on http://{args.host}:{args.port}/rag")
            server.serve_forever()
            return 0
        result = run_rag(
            query=args.query,
            model_path=args.model_path,
            vector_db_path=args.vector_db_path,
            engine=args.engine,
            memory_limit_mb=args.memory_limit_mb,
            network_blocked=args.enforce_network_block,
        )
        emit_json(result)
        return 0 if result.get("success") else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
