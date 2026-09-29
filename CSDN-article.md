# 8×RTX 4090 硬刚 DeepSeek-V4-Flash-0731：从官方推理到 vLLM OpenAI API 的完整踩坑记录

最近拿到一台独占 GPU 服务器，配置是 8 张 RTX 4090。目标很简单：使用官方 DeepSeek-V4-Flash-0731 权重，把模型部署成可以给 OpenWebUI、RAG 和业务系统调用的 OpenAI-compatible API。

真正部署以后，连续遇到了 SM89、DeepGEMM、CUDA Graph OOM、KV Cache OOM 等问题。这里把完整过程记录下来。

## 一、硬件

- 8 × NVIDIA GeForce RTX 4090
- 单卡约 24 GB，总显存约 192 GB
- Compute Capability：8.9 / SM89
- 2 × Intel Xeon Gold 6530
- RAM 约 503 GiB

关键点：RTX 4090 是 SM89，而且这台机器没有 NVLink。

## 二、先验证 Docker GPU

```bash
docker run --rm --gpus all   nvidia/cuda:13.0.0-base-ubuntu24.04   nvidia-smi
```

确认容器可以看到全部 8 张卡。

## 三、先验证官方模型

先使用 DeepSeek 官方 inference code 验证模型本身：

```bash
export TILELANG_TARGET=cuda
export CUDA_HOME=/usr/local/cuda-13.0
export PATH=$CUDA_HOME/bin:$PATH

CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6,7 torchrun --nproc-per-node 8   generate.py   --ckpt-path /data/models/DeepSeek-V4-Flash-0731-converted-mp8   --config config.json   --interactive
```

最终出现：

```text
I'm DeepSeek 👋
```

并可以正常聊天。

这一步证明官方权重和 8 卡分布式推理本身没问题。

## 四、官方 vLLM 遇到 SM89 问题

最初使用：

```text
vllm/vllm-openai:latest
```

启动 DeepSeek-V4 时遇到：

```text
Unsupported architecture
```

排查后确认问题与 DeepGEMM 路径和 RTX 4090 的 SM89 架构有关。

因此没有修改官方模型权重，而是换用 SM89 runtime：

```text
ghcr.io/yhfgyyf/vllm-deepseek-v4-sm89:0.28.1rc1-vision11-sm89-sm120-cu130
```

注意：第三方的是 runtime，不是模型权重。

## 五、第一个坑：CUDA Graph OOM

SM89 runtime 已经可以进入 DeepSeek-V4 实际模型执行，但 CUDA Graph capture 阶段出现：

```text
Triton Error [CUDA]: out of memory
```

于是采用：

```text
--enforce-eager
--compilation-config '{"cudagraph_mode":"NONE"}'
```

## 六、第二个坑：KV Cache OOM

继续启动后出现：

```text
Available KV cache memory: 0.16 GiB
```

32768 tokens 需要约 1.7 GiB KV Cache，因此 vLLM 无法启动。

最终增加：

```text
--cpu-offload-gb 8
```

终于成功。

## 七、最终运行参数

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

## 八、API Server 成功

启动日志出现：

```text
Starting vLLM server on http://0.0.0.0:8000
Application startup complete.
```

健康检查：

```bash
curl http://127.0.0.1:19090/health
```

返回 HTTP 200。

模型：

```bash
curl http://127.0.0.1:19090/v1/models
```

返回：

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

## 九、为什么不直接追求 1M Context？

模型配置里的最大上下文长度，不等于当前硬件实际能够提供的 KV Cache。

这台 8×4090 的 GPU 显存已经非常紧张，因此生产参数需要结合实际 KV Cache、CPU Offload、并发和业务请求长度测试。

## 十、下一步性能压测

当前参数首先追求稳定：

```text
max-num-seqs=1
max-num-batched-tokens=2048
```

下一步应该实测：

```text
1 / 2 / 4 / 8 ... 并发
```

观察：

- TTFT
- ITL
- tokens/s
- 总吞吐
- GPU 利用率
- KV Cache
- CPU Offload
- OOM

最终找到这台 8×4090 的实际最佳配置。

## 总结

这次真正有价值的不是一条启动命令，而是完整的排障路径：

```text
8×4090
→ Docker GPU
→ 官方模型
→ 官方 inference 成功
→ 官方 vLLM
→ SM89 / DeepGEMM 问题
→ SM89 runtime
→ CUDA Graph OOM
→ Eager
→ KV Cache OOM
→ CPU Offload
→ vLLM API Server
→ OpenAI-compatible API
```

> 重要：公开文章和 GitHub 不要发布真实 API Key、公司内网 IP、密码等生产信息。第三方 runtime 也应在生产使用前自行审阅来源、代码、许可证和安全性。
