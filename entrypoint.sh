#!/bin/bash
set -e

MODELS_DIR="/models"
MODELS_READY="$MODELS_DIR/.models_ready"
RETRY_DELAY=60

download_model() {
    local repo="$1"
    local file="$2"
    local dest="$MODELS_DIR/$file"

    if [ -f "$dest" ]; then
        echo "[entrypoint] $file already exists, skipping"
        return 0
    fi

    while true; do
        echo "[entrypoint] Downloading $file from $repo..."
        if curl -L -C - --retry 3 --retry-delay 10 -o "$dest.tmp" \
            "https://huggingface.co/$repo/resolve/main/$file"; then
            mv "$dest.tmp" "$dest"
            echo "[entrypoint] $file OK"
            return 0
        fi
        rm -f "$dest.tmp"
        echo "[entrypoint] Failed, retrying in ${RETRY_DELAY}s..."
        sleep $RETRY_DELAY
    done
}

# Models already downloaded -> offline mode
if [ -f "$MODELS_READY" ]; then
    echo "[entrypoint] Models ready, starting server"
    export LLAMA_OFFLINE=1
    exec /app/llama-server "$@"
fi

echo "[entrypoint] Downloading models..."
mkdir -p "$MODELS_DIR"

download_model "ggml-org/gemma-4-E2B-it-GGUF" "gemma-4-e2b-it-Q8_0.gguf"
download_model "NousResearch/Hermes-3-Llama-3.1-8B-GGUF" "Hermes-3-Llama-3.1-8B.Q4_K_M.gguf"
download_model "nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF" "NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf"
download_model "unsloth/Qwen3.5-2B-GGUF" "Qwen3.5-2B-Q8_0.gguf"
download_model "NousResearch/Hermes-3-Llama-3.2-3B-GGUF" "Hermes-3-Llama-3.2-3B.Q8_0.gguf"

touch "$MODELS_READY"
echo "[entrypoint] All models ready"
export LLAMA_OFFLINE=1

echo "[entrypoint] Starting llama-server..."
exec /app/llama-server "$@"
