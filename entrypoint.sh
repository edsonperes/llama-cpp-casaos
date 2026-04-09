#!/bin/bash
set -e

MODELS_READY="/root/.cache/llama.cpp/.models_ready"
RETRY_DELAY=30
MAX_RETRIES=20

download_model() {
    local hf_repo="$1"
    local hf_file="$2"
    local attempt=0

    while [ $attempt -lt $MAX_RETRIES ]; do
        attempt=$((attempt + 1))
        echo "[entrypoint] Downloading $hf_file from $hf_repo (attempt $attempt/$MAX_RETRIES)..."

        if /app/llama-server --hf-repo "$hf_repo" --hf-file "$hf_file" --no-warmup --ctx-size 64 --host 127.0.0.1 --port 19999 &
        then
            local pid=$!
            # Wait for model to load or fail (max 120s)
            local wait=0
            while [ $wait -lt 120 ]; do
                if ! kill -0 $pid 2>/dev/null; then
                    break
                fi
                # Check if server is ready (model loaded)
                if curl -sf http://127.0.0.1:19999/health >/dev/null 2>&1; then
                    echo "[entrypoint] $hf_file downloaded and verified OK"
                    kill $pid 2>/dev/null || true
                    wait $pid 2>/dev/null || true
                    return 0
                fi
                sleep 2
                wait=$((wait + 2))
            done
            kill $pid 2>/dev/null || true
            wait $pid 2>/dev/null || true
        fi

        echo "[entrypoint] Download failed, retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
    done

    echo "[entrypoint] ERROR: Failed to download $hf_file after $MAX_RETRIES attempts"
    return 1
}

# If models already downloaded, go straight to offline mode
if [ -f "$MODELS_READY" ]; then
    echo "[entrypoint] Models already cached, starting in offline mode"
    export LLAMA_OFFLINE=1
    exec /app/llama-server "$@"
fi

echo "[entrypoint] First boot - downloading models..."
mkdir -p /root/.cache/llama.cpp

# Download each model defined in models.ini
ALL_OK=true

# Gemma 4 E2B
if download_model "ggml-org/gemma-4-E2B-it-GGUF" "gemma-4-e2b-it-Q8_0.gguf"; then
    echo "[entrypoint] Gemma 4 E2B OK"
else
    ALL_OK=false
fi

# Qwen 3.5 2B
if download_model "unsloth/Qwen3.5-2B-GGUF" "Qwen3.5-2B-Q8_0.gguf"; then
    echo "[entrypoint] Qwen 3.5 2B OK"
else
    ALL_OK=false
fi

if [ "$ALL_OK" = true ]; then
    touch "$MODELS_READY"
    echo "[entrypoint] All models downloaded successfully, future boots will be offline"
    export LLAMA_OFFLINE=1
else
    echo "[entrypoint] WARNING: Some models failed to download, will retry on next boot"
fi

echo "[entrypoint] Starting llama-server..."
exec /app/llama-server "$@"
