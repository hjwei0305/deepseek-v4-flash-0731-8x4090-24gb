#!/usr/bin/env bash
set -e
BASE_URL="${BASE_URL:-http://127.0.0.1:19090}"
MODEL="${MODEL:-DeepSeek-V4-Flash-0731}"

test -n "${VLLM_API_KEY:-}" || { echo "Please export VLLM_API_KEY first."; exit 1; }

curl -fsS "${BASE_URL}/v1/chat/completions"   -H "Content-Type: application/json"   -H "Authorization: Bearer ${VLLM_API_KEY}"   -d "{
    "model": "${MODEL}",
    "messages": [{"role":"user","content":"你好，请用一句话介绍一下自己。"}],
    "max_tokens": 100
  }"
echo
