# Offline Local RAG Runtime

This project cannot make a hosted Supabase Edge Function read files from a
user's PC. Offline secure RAG therefore uses a local loopback runtime:

- Flutter stores the local model path, vector DB path, and runtime URL.
- Edge LLM Playground routes to `http://127.0.0.1:8765/rag` when offline secure
  mode blocks external APIs and both local paths are configured.
- The hosted `ai-hub` function continues to block external provider fetches and
  returns `offline_blocked=true` / `localRuntimePending` when a browser or other
  caller still reaches the cloud boundary.

## Start The Runtime

Create a local corpus directory and a local model marker or actual model file:

```powershell
New-Item -ItemType Directory -Force C:\rag\lancedb | Out-Null
Set-Content C:\rag\lancedb\policy.md "Offline secure mode answers from local documents only."
Set-Content C:\models\pleias-rag.gguf "replace with a real local model file"
python scripts\local_rag_runtime.py --serve `
  --model-path C:\models\pleias-rag.gguf `
  --vector-db-path C:\rag\lancedb `
  --memory-limit-mb 8192 `
  --enforce-network-block
```

Then set the app's offline secure mode values:

- Local model path: `C:\models\pleias-rag.gguf`
- Local vector DB path: `C:\rag\lancedb`
- Local RAG runtime URL: `http://127.0.0.1:8765/rag`
- External API blocking: on

## Validation

One-shot validation without starting the HTTP server:

```powershell
python scripts\local_rag_runtime.py `
  --query "How does offline secure mode answer?" `
  --model-path C:\models\pleias-rag.gguf `
  --vector-db-path C:\rag\lancedb `
  --memory-limit-mb 8192 `
  --enforce-network-block
```

Expected success contract:

- `success=true`
- `offline_only=true`
- `network_blocked=true`
- `memory_peak_mb <= 8192`
- `citations` contains at least one local source

Expected safe failure contract:

- missing model path returns `success=false` and `status=missingModel`
- missing vector DB path returns `success=false`
- the app does not fall back to external providers while external API blocking
  is enabled

## Current Limit

The bundled Python runtime is a deterministic offline extractive RAG harness.
It validates the local-only transport, citation contract, and 8GB memory gate.
Replacing the answer builder with a real Pleias/llama.cpp/Ollama command is the
next production hardening step for real generative local inference.
