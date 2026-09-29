# DeepSeek-V4-Flash-0731 8×RTX 4090 24GB 部署实战与踩坑记录

8×RTX 4090（SM89）部署 DeepSeek-V4-Flash-0731 的真实部署实战记录，仅供参考。

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
