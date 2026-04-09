# llama.cpp Server - CasaOS (NVIDIA CUDA)

Imagem Docker do [llama.cpp](https://github.com/ggerganov/llama.cpp) server com suporte a GPU NVIDIA CUDA, otimizada para **Tesla P4** (8GB VRAM) e compativel com **CasaOS**.

Inclui WebUI integrada para chat acessivel via navegador.

## Pre-requisitos

- CasaOS instalado
- GPU NVIDIA com drivers instalados
- [nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html) instalado e configurado
- Modelo GGUF (baixar do [HuggingFace](https://huggingface.co/models?sort=trending&search=gguf))

## Instalacao no CasaOS

1. No CasaOS, va em **App Store > Custom Install > Import**
2. Cole o conteudo do `docker-compose.yaml` deste repositorio
3. Coloque seu modelo `.gguf` em `/DATA/AppData/llama-cpp/models/`
4. Edite a variavel `LLAMA_ARG_MODEL` com o nome do seu modelo (ex: `/models/qwen2.5-7b-q4_k_m.gguf`)
5. Instale e acesse em `http://seu-ip:8080`

## Uso Standalone (Docker Compose)

```bash
# Criar diretorio de modelos
mkdir -p /DATA/AppData/llama-cpp/models

# Baixar um modelo (exemplo: Qwen2.5 7B Q4_K_M)
# Coloque o arquivo .gguf em /DATA/AppData/llama-cpp/models/

# Editar docker-compose.yaml com o nome do modelo
# Iniciar
docker compose up -d
```

Acesse a WebUI em `http://localhost:8080`

## Variaveis de Ambiente

| Variavel | Padrao | Descricao |
|---|---|---|
| `LLAMA_ARG_MODEL` | `/models/model.gguf` | Caminho do modelo GGUF dentro do container |
| `LLAMA_ARG_N_GPU_LAYERS` | `999` | Layers offloaded para GPU (999 = todas) |
| `LLAMA_ARG_CTX_SIZE` | `2048` | Tamanho do contexto (0 = usa valor do modelo) |
| `LLAMA_ARG_FLASH_ATTN` | `1` | Habilita Flash Attention (recomendado) |
| `LLAMA_ARG_THREADS` | `4` | Threads CPU para processamento |
| `LLAMA_ARG_HOST` | `0.0.0.0` | Endereco de bind (definido na imagem) |
| `LLAMA_ARG_PORT` | `8080` | Porta do servidor |
| `LLAMA_ARG_HF_REPO` | - | Repositorio HuggingFace para download automatico |
| `LLAMA_ARG_HF_FILE` | - | Arquivo especifico do repo HuggingFace |

## Recomendacoes para Tesla P4 (8GB VRAM)

- Use modelos quantizados **Q4_K_M** ou **Q5_K_M**
- Modelos ate **7B** parametros cabem confortavelmente
- Modelos **13B Q4_K_M** cabem com contexto reduzido (~2048)
- `LLAMA_ARG_CTX_SIZE=2048` e seguro para a maioria dos casos
- `LLAMA_ARG_N_GPU_LAYERS=999` para offload total

## Download Automatico de Modelos

Em vez de baixar manualmente, voce pode usar as variaveis HuggingFace:

```yaml
environment:
  - LLAMA_ARG_HF_REPO=Qwen/Qwen2.5-7B-Instruct-GGUF
  - LLAMA_ARG_HF_FILE=qwen2.5-7b-instruct-q4_k_m.gguf
```

O modelo sera baixado automaticamente na primeira execucao.

## Build Local

```bash
docker build -t llama-cpp-casaos:latest .
```

Para alterar a versao do llama.cpp:

```bash
docker build --build-arg LLAMA_CPP_VERSION=b5000 -t llama-cpp-casaos:b5000 .
```

## Licenca

Este projeto usa o codigo do [llama.cpp](https://github.com/ggerganov/llama.cpp) sob licenca MIT.
