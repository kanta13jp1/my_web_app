#!/usr/bin/env bash
set -euo pipefail
mkdir -p /tmp/jev-backend
cd /tmp/jev-backend
curl -fsSL https://github.com/ggml-org/llama.cpp/releases/download/b6000/llama-b6000-bin-ubuntu-x64.zip -o llama.zip
echo '66244356dd242ae3a2510929ec4a840db65a3f9e7ad712918dbf02a266badfa5  llama.zip' | sha256sum -c
unzip -q llama.zip
curl -fsSL https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf -o model.gguf
sha256sum model.gguf > model.sha256
server=$(find . -type f -name llama-server | head -1)
chmod +x "$server"
LD_LIBRARY_PATH="$(dirname "$server")" "$server" -m model.gguf --host 127.0.0.1 --port 8000 -c 8192 -t 2 --alias qwen-local > llama.log 2>&1 &
echo $! > llama.pid
curl -fsSL https://github.com/oven-sh/bun/releases/download/bun-v1.2.22/bun-linux-x64.zip -o bun.zip
unzip -q bun.zip
git clone --quiet https://github.com/githubnext/localjev.git
git -C localjev checkout --quiet 3f23e36e1a3bff46c7e83e8e3781d3512bc82021
cd localjev
LOCALJEV_UPSTREAM=http://127.0.0.1:8000 LOCALJEV_UPSTREAM_MODEL=qwen-local LOCALJEV_MAX_OUTPUT_TOKENS=512 LOCALJEV_TIMEOUT_SECONDS=55 LOCALJEV_MALFORMED_RETRIES=0 ../bun-linux-x64/bun run src/index.ts > ../localjev.log 2>&1 &
echo $! > ../localjev.pid
for i in $(seq 1 60); do
  if curl -fsS http://127.0.0.1:8000/health >/dev/null; then exit 0; fi
  sleep 2
done
exit 1
