#!/usr/bin/env bash
set -e
BASE_URL="${BASE_URL:-http://127.0.0.1:19090}"
echo "== health =="
curl -fsS "${BASE_URL}/health"
echo
echo "== models =="
curl -fsS "${BASE_URL}/v1/models"
echo
