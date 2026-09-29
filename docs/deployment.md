# 部署过程

## 1. 验证 Docker GPU

```bash
docker run --rm --gpus all   nvidia/cuda:13.0.0-base-ubuntu24.04   nvidia-smi
```

确认容器可以看到 8 张 RTX 4090。

## 2. 官方模型先单独验证

本次使用官方 DeepSeek-V4-Flash-0731。

官方 inference 的 8 卡验证：

```bash
export TILELANG_TARGET=cuda
export CUDA_HOME=/usr/local/cuda-13.0
export PATH=$CUDA_HOME/bin:$PATH

CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 torchrun --nproc-per-node 8   generate.py   --ckpt-path /data/models/DeepSeek-V4-Flash-0731-converted-mp8   --config config.json   --interactive
```

最终可以进入 `I'm DeepSeek 👋` 并正常交互。

## 3. 官方 vLLM 路径

最初使用 `vllm/vllm-openai:latest`，启动 DeepSeek-V4 时遇到 `Unsupported architecture`。当前服务器 GPU 为 SM89 / RTX 4090，DeepGEMM 路径存在架构限制。

## 4. SM89 runtime

最终使用：

```text
ghcr.io/yhfgyyf/vllm-deepseek-v4-sm89:0.28.1rc1-vision11-sm89-sm120-cu130
```

注意：这是 runtime，不是模型权重。模型仍通过 `/data/models/DeepSeek-V4-Flash-0731:/model:ro` 挂载。

## 5. CUDA Graph OOM

SM89 runtime 首次启动进入实际模型执行后，在 CUDA Graph capture 阶段出现 Triton CUDA OOM。

采用：

```text
--enforce-eager
--compilation-config '{"cudagraph_mode":"NONE"}'
```

## 6. KV Cache OOM

后续出现：

```text
Available KV cache memory: 0.16 GiB
```

32768 tokens 需要约 1.7 GiB KV Cache，因此无法启动。

最终增加：

```text
--cpu-offload-gb 8
```

之后 API Server 成功启动。

## 7. API 验证

```bash
curl http://127.0.0.1:19090/health
curl http://127.0.0.1:19090/v1/models
```

模型名称：

```text
DeepSeek-V4-Flash-0731
```

OpenAPI：

```text
http://<SERVER_IP>:19090/openapi.json
```

Chat：

```bash
curl http://<SERVER_IP>:19090/v1/chat/completions   -H "Content-Type: application/json"   -H "Authorization: Bearer <YOUR_API_KEY>"   -d '{
    "model": "DeepSeek-V4-Flash-0731",
    "messages": [
      {"role": "user", "content": "你好，请简单介绍一下自己。"}
    ],
    "max_tokens": 100
  }'
```

## 8. Compose

当前服务器使用 Docker Compose v1.29.2，因此命令是：

```bash
docker-compose config
docker-compose up -d
docker-compose logs -f
```

不是 `docker compose`。
