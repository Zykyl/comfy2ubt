#!/usr/bin/env bash
# ComfyUI 실행. 추가 인자는 main.py 로 그대로 전달됩니다.
#   예) ./run.sh --listen 0.0.0.0 --port 8188
#       ./run.sh --cpu
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -x "$ROOT/venv/bin/python" ]] || { echo "먼저 ./install.sh 를 실행하세요." >&2; exit 1; }
cd "$ROOT/ComfyUI"
export HF_HUB_OFFLINE=1 TRANSFORMERS_OFFLINE=1
exec "$ROOT/venv/bin/python" main.py --disable-api-nodes "$@"
