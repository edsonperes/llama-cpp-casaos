ARG CUDA_VERSION=12.8.1
ARG UBUNTU_VERSION=24.04

# ============================================================================
# Build stage
# ============================================================================
FROM nvidia/cuda:${CUDA_VERSION}-devel-ubuntu${UBUNTU_VERSION} AS build

ARG LLAMA_CPP_VERSION=master
# Tesla P4 = sm_61 (Pascal)
ARG CUDA_DOCKER_ARCH=61

RUN apt-get update && \
    apt-get install -y gcc-14 g++-14 build-essential cmake git libssl-dev libgomp1 && \
    rm -rf /var/lib/apt/lists/*

ENV CC=gcc-14 CXX=g++-14 CUDAHOSTCXX=g++-14

WORKDIR /app

RUN git clone --depth 1 --branch ${LLAMA_CPP_VERSION} \
    https://github.com/ggerganov/llama.cpp.git .

RUN cmake -B build \
    -DGGML_NATIVE=OFF \
    -DGGML_CUDA=ON \
    -DGGML_BACKEND_DL=ON \
    -DGGML_CPU_ALL_VARIANTS=ON \
    -DLLAMA_BUILD_TESTS=OFF \
    -DCMAKE_CUDA_ARCHITECTURES=${CUDA_DOCKER_ARCH} \
    -DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined \
    . && \
    cmake --build build --config Release -j$(nproc)

RUN mkdir -p /app/lib && \
    find build -name "*.so*" -exec cp -P {} /app/lib \;

# ============================================================================
# Runtime stage
# ============================================================================
FROM nvidia/cuda:${CUDA_VERSION}-runtime-ubuntu${UBUNTU_VERSION}

RUN apt-get update && \
    apt-get install -y libgomp1 curl && \
    apt autoremove -y && apt clean -y && \
    rm -rf /tmp/* /var/tmp/* && \
    find /var/cache/apt/archives /var/lib/apt/lists -not -name lock -type f -delete && \
    find /var/cache -type f -delete

COPY --from=build /app/lib/ /app/
COPY --from=build /app/build/bin/llama-server /app/
COPY models.ini /app/models.ini
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

WORKDIR /app

ENV LLAMA_ARG_HOST=0.0.0.0
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility

EXPOSE 8080

HEALTHCHECK --interval=60s --timeout=10s --start-period=300s --retries=3 \
    CMD ["curl", "-f", "http://localhost:8080/health"]

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["--models-preset", "/app/models.ini", "--models-max", "1"]
