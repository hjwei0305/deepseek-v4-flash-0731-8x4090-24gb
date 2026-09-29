# Troubleshooting

本次服务器使用 `docker-compose 1.29.2`。

## Unsupported architecture

RTX 4090 是 SM89。官方 vLLM latest 的 DeepGEMM 路径可能不适配 SM89。先确认：

```bash
nvidia-smi
```

再确认 GPU capability。

## CUDA Graph OOM

如果错误发生在 CUDA Graph capture 阶段，可测试：

```text
--enforce-eager
--compilation-config '{"cudagraph_mode":"NONE"}'
```

## KV Cache OOM

典型：

```text
Available KV cache memory: 0.16 GiB
```

处理顺序：

1. 降低 `max_model_len`
2. 降低并发
3. 调整 `gpu-memory-utilization`
4. 允许 CPU offload
5. 再做吞吐压测

本次最终使用：

```text
--cpu-offload-gb 8
```

## /health 200 但没有正文

正常。健康检查可能返回 HTTP 200、content-length 0。

## /docs 空白

如果 `/docs` 返回 200，但浏览器空白，可以直接访问：

```text
/openapi.json
```

如果 JSON 正常，说明后端 API 本身已经正常。

## API Key

公开仓库不要提交真实 Key。推荐：

```yaml
VLLM_API_KEY: ${VLLM_API_KEY}
```

并在 `.env` 中设置真实 Key，同时把 `.env` 加入 `.gitignore`。
