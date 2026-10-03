"""Bounded synthetic Japanese expense evaluation; never production records."""
import hashlib
import importlib.metadata
import json
import platform
import time
from datetime import datetime, timezone
from pathlib import Path

SDK_REVISION = "42626c348753fbb17572a813127df2278a1ec527"
MODEL_REVISION = "e4e9ddf21a7b1903b7acffd8814ad4307bf63a67"
CASES = [
    ("電気代", "utilities"),
    ("水道料金", "utilities"),
    ("病院の診察料", "medical"),
    ("電車の切符", "transport"),
    ("家賃", "housing"),
    ("自炊用の野菜と肉", "food"),
]


def main():
    import laya
    import torch
    from huggingface_hub import snapshot_download
    from laya_system_one_server import validate_response

    torch.set_num_threads(2)
    # Extract the app's exact 12 labels without installing Flutter or copying a
    # second independently maintained category list.
    import re
    source = Path("lib/services/jev_instant_classifier_service.dart").read_text()
    block = source.split("defaultCategories = <JevChoice>[")[1].split("];", 1)[0]
    criteria = dict(re.findall(r"id: '([^']+)',\s*label: '[^']+',\s*description: '([^']+)'", block))
    if len(criteria) != 12:
        raise ValueError("App category extraction changed; review the fixture")
    questions = {"classification": {"type": "choice", "instructions":
        "日本の一般的な個人家計簿・支出管理における品目分類", "criteria": criteria}}
    fixture = json.dumps({"cases": CASES, "questions": questions}, ensure_ascii=False, sort_keys=True)
    started = time.perf_counter()
    model_path = snapshot_download("convaiinnovations/laya-multilingual", revision=MODEL_REVISION)
    download_seconds = time.perf_counter() - started
    started = time.perf_counter()
    agent = laya.load(model_path, device="cpu")
    load_seconds = time.perf_counter() - started
    for _ in range(2):
        validate_response(agent.predict(CASES[0][0], questions), questions)
    results = []
    for text, expected in CASES:
        for repeat in range(3):
            started = time.perf_counter()
            output = validate_response(agent.predict(text, questions), questions)
            elapsed_ms = (time.perf_counter() - started) * 1000
            answer = output["answers"]["classification"]
            results.append({"input": text, "expected": expected, "repeat": repeat,
                "answer": answer, "latency_ms": elapsed_ms,
                "matches_expected": answer["choice"] == expected,
                "exceeds_direct_client_800ms": elapsed_ms > 800})
    report = {"observed_at": datetime.now(timezone.utc).isoformat(),
        "kind": "synthetic_real_model_cpu_sdk", "sdk_revision": SDK_REVISION,
        "model_revision": MODEL_REVISION, "platform": platform.platform(),
        "cpu": platform.processor(), "threads": 2, "warmups": 2,
        "download_seconds": download_seconds, "load_seconds": load_seconds,
        "fixture_sha256": hashlib.sha256(fixture.encode()).hexdigest(),
        "app_category_source_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "packages": {p: importlib.metadata.version(p) for p in
            ("torch", "transformers", "laya", "huggingface_hub", "numpy")},
        "timing_scope": "SDK call including validation; no HTTP/browser/download/load",
        "limitations": "6 synthetic cases with 3 repeats, not general accuracy, browser timing or calibration",
        "results": results}
    Path("laya-real-results.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
