#!/bin/bash
set -e

MODELS_DIR="/models"
MODELS_READY="$MODELS_DIR/.models_ready"
RETRY_DELAY=60

# Verify file starts with "GGUF" magic bytes
verify_gguf() {
    local file="$1"
    [ -f "$file" ] || return 1
    local magic
    magic=$(head -c 4 "$file" 2>/dev/null || true)
    [ "$magic" = "GGUF" ]
}

download_model() {
    local repo="$1"
    local file="$2"
    local dest="$MODELS_DIR/$file"

    if verify_gguf "$dest"; then
        echo "[entrypoint] $file already exists and valid, skipping"
        return 0
    fi

    if [ -f "$dest" ]; then
        echo "[entrypoint] $file exists but is invalid, removing"
        rm -f "$dest"
    fi

    while true; do
        echo "[entrypoint] Downloading $file from $repo..."
        if curl -fL -C - --retry 5 --retry-delay 10 -o "$dest.tmp" \
            "https://huggingface.co/$repo/resolve/main/$file"; then
            if verify_gguf "$dest.tmp"; then
                mv "$dest.tmp" "$dest"
                echo "[entrypoint] $file OK ($(du -h "$dest" | cut -f1))"
                return 0
            else
                echo "[entrypoint] Downloaded file is not valid GGUF, retrying"
                rm -f "$dest.tmp"
            fi
        else
            rm -f "$dest.tmp"
        fi
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
download_model "nvidia/NVIDIA-Nemotron-3-Nano-4B-GGUF" "NVIDIA-Nemotron3-Nano-4B-Q4_K_M.gguf"
download_model "unsloth/Qwen3.5-2B-GGUF" "Qwen3.5-2B-Q8_0.gguf"

touch "$MODELS_READY"
echo "[entrypoint] All models ready"
export LLAMA_OFFLINE=1

echo "[entrypoint] Starting llama-server..."
exec /app/llama-server "$@"
