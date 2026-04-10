#!/bin/bash
set -e

MODELS_READY="/root/.cache/llama.cpp/.models_ready"
RETRY_DELAY=60

download_model() {
    local hf_repo="$1"
    local hf_file="$2"
    local attempt=0

    while true; do
        attempt=$((attempt + 1))
        echo "[entrypoint] Downloading $hf_file from $hf_repo (attempt $attempt)..."

        /app/llama-server --hf-repo "$hf_repo" --hf-file "$hf_file" --no-warmup --ctx-size 64 --host 127.0.0.1 --port 19999 &
        local pid=$!

        local elapsed=0
        while [ $elapsed -lt 300 ]; do
            if ! kill -0 $pid 2>/dev/null; then
                break
            fi
            if curl -sf http://127.0.0.1:19999/health >/dev/null 2>&1; then
                echo "[entrypoint] $hf_file downloaded OK"
                kill $pid 2>/dev/null || true
                wait $pid 2>/dev/null || true
                return 0
            fi
            sleep 2
            elapsed=$((elapsed + 2))
        done

        kill $pid 2>/dev/null || true
        wait $pid 2>/dev/null || true

        echo "[entrypoint] Failed, retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
    done
}

# Models already cached -> offline mode
if [ -f "$MODELS_READY" ]; then
    echo "[entrypoint] Models cached, starting in offline mode"
    export LLAMA_OFFLINE=1
    exec /app/llama-server "$@"
fi

echo "[entrypoint] Downloading models (retries until all succeed)..."
mkdir -p /root/.cache/llama.cpp

download_model "ggml-org/gemma-4-E2B-it-GGUF" "gemma-4-e2b-it-Q8_0.gguf"
echo "[entrypoint] Gemma 4 E2B OK"

download_model "nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF" "NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf"
echo "[entrypoint] Nemotron 3 Nano 4B OK"

download_model "unsloth/Qwen3.5-2B-GGUF" "Qwen3.5-2B-Q8_0.gguf"
echo "[entrypoint] Qwen 3.5 2B OK"

touch "$MODELS_READY"
echo "[entrypoint] All models ready, future boots will be offline"
export LLAMA_OFFLINE=1

echo "[entrypoint] Starting llama-server..."
exec /app/llama-server "$@"
