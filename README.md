# DeepSeek-V4-Flash-0731 on 8×RTX 4090

8×RTX 4090（SM89）部署 DeepSeek-V4-Flash-0731 的真实生产实战记录。

## 硬件

- 8 × NVIDIA GeForce RTX 4090
- 单卡约 24 GB，总显存约 192 GB
- Compute Capability 8.9 / SM89
- 2 × Intel Xeon Gold 6530
- RAM 约 503 GiB

## 最终验证

已经验证：

- Docker + NVIDIA Container Toolkit 可识别全部 8 GPU
- 官方 DeepSeek-V4-Flash-0731 权重可通过官方 inference code 在 8 卡正常推理
- 官方 vLLM latest 在 RTX 4090 / SM89 上遇到 DeepGEMM architecture limitation
- 使用 SM89 专用 vLLM runtime 后成功启动 DeepSeek-V4
- 处理过 CUDA Graph OOM 与 KV Cache OOM
- 最终通过 Eager + CPU Offload 成功提供 OpenAI-compatible API
- `/health` 返回 HTTP 200
- `/v1/models` 返回 `DeepSeek-V4-Flash-0731`

## 最终验证参数

```text
TP=8
EP=enabled
moe-backend=auto
attention-backend=FLASHINFER_MLA_SPARSE_DSV4
kv-cache-dtype=fp8_ds_mla
block-size=256
max-num-seqs=1
max-num-batched-tokens=2048
gpu-memory-utilization=0.90
cpu-offload-gb=8
enforce-eager
cudagraph_mode=NONE
tokenizer-mode=deepseek_v4
reasoning-parser=deepseek_v4
```

## 目录

```text
README.md
CSDN-article.md
docker/docker-compose.yml
docs/deployment.md
docs/troubleshooting.md
scripts/check-api.sh
scripts/test-chat.sh
```

## 快速检查

```bash
docker-compose config
docker-compose up -d
docker-compose logs -f
curl http://127.0.0.1:19090/health
curl http://127.0.0.1:19090/v1/models
```

## 安全

不要把真实 API Key、公司内网 IP、密码提交到公开 GitHub。Compose 推荐使用 `.env` 注入 Key，并把 `.env` 加入 `.gitignore`。

## 后续性能优化

当前配置首先追求稳定启动。下一阶段应实际压测 `max-num-seqs`、`max-num-batched-tokens`、KV Cache、CPU Offload、TTFT、ITL 和总吞吐，而不是直接猜参数。

> 模型权重保持官方版本；第三方部分是用于适配 SM89 的运行时镜像。生产环境使用前请自行审阅其来源、代码、许可证和安全性。
