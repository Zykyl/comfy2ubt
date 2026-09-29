#!/usr/bin/env bash
# ComfyUI 오프라인 설치 스크립트 (Ubuntu 24.04 / x86_64 / Python 3.12)
# 사용법: ./install.sh [--clean]
#   --clean : 설치 후 재조립한 wheel 캐시(packages/wheelhouse)를 삭제해 디스크 공간 확보
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG="$ROOT/packages"
HOUSE="$PKG/wheelhouse"
VENV="$ROOT/venv"
TOOLS="$ROOT/.tools"
CLEAN=0
[[ "${1:-}" == "--clean" ]] && CLEAN=1

log() { echo -e "\033[1;32m[install]\033[0m $*"; }
die() { echo -e "\033[1;31m[error]\033[0m $*" >&2; exit 1; }

[[ "$(uname -m)" == "x86_64" ]] || die "x86_64 전용 패키지입니다 (현재: $(uname -m))."
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  [[ "${VERSION_ID:-}" == "24.04" ]] || echo "경고: Ubuntu 24.04 기준 패키지입니다 (현재: ${PRETTY_NAME:-unknown})."
fi

SUDO=""
[[ $EUID -ne 0 ]] && SUDO="sudo"

# 1) Python 3.12 확인 (없으면 동봉된 .deb 설치)
if ! command -v python3.12 >/dev/null 2>&1; then
  log "python3.12 가 없어 동봉된 .deb 를 설치합니다."
  $SUDO dpkg -i "$PKG"/debs/*.deb
fi
PY="$(command -v python3.12)"
log "Python: $PY ($($PY --version))"

# 2) 분할된 대용량 wheel 재조립 + 체크섬 검증
mkdir -p "$HOUSE"
cp -u "$PKG"/wheels/*.whl "$HOUSE"/
for first in "$PKG"/split/*.whl.part00; do
  name="$(basename "${first%.part00}")"
  if [[ ! -f "$HOUSE/$name" ]]; then
    log "재조립: $name"
    cat "$PKG/split/$name".part* > "$HOUSE/$name.tmp"
    mv "$HOUSE/$name.tmp" "$HOUSE/$name"
  fi
done
log "SHA256 검증 중..."
( cd "$HOUSE" && grep '\.whl$' "$PKG/SHA256SUMS" | sha256sum -c --quiet - ) \
  || die "체크섬 불일치. 저장소를 다시 복사하세요 (git lfs 없이 clone 했는지 확인)."

# 3) uv 바이너리 추출 (uv wheel 안에 들어 있음, 인터넷 불필요)
if [[ ! -x "$TOOLS/uv" ]]; then
  mkdir -p "$TOOLS"
  "$PY" - "$HOUSE" "$TOOLS" <<'EOF'
import sys, zipfile, glob, os
house, tools = sys.argv[1], sys.argv[2]
whl = glob.glob(os.path.join(house, "uv-*.whl"))[0]
with zipfile.ZipFile(whl) as z:
    for n in z.namelist():
        if n.endswith("/scripts/uv"):
            with open(os.path.join(tools, "uv"), "wb") as f:
                f.write(z.read(n))
os.chmod(os.path.join(tools, "uv"), 0o755)
EOF
fi
UV="$TOOLS/uv"
export UV_OFFLINE=1 UV_NO_CACHE=1 UV_PYTHON_DOWNLOADS=never

# 4) 가상환경 생성
if [[ ! -x "$VENV/bin/python" ]]; then
  log "가상환경 생성: $VENV"
  if ! "$UV" venv --python "$PY" "$VENV"; then
    log "uv venv 실패 → python3 -m venv 로 재시도"
    "$PY" -m venv "$VENV" 2>/dev/null || { $SUDO dpkg -i "$PKG"/debs/*.deb; "$PY" -m venv "$VENV"; }
  fi
fi

# 5) 패키지 설치 (완전 오프라인)
log "패키지 설치 중 (수 분 소요)..."
"$UV" pip install --python "$VENV/bin/python" --offline --no-index \
  --find-links "$HOUSE" -r "$ROOT/requirements-lock.txt" pip wheel

# pip 를 쓰고 싶을 때도 오프라인으로 동작하도록 설정
cat > "$VENV/pip.conf" <<EOF
[global]
no-index = true
find-links = $HOUSE
EOF

log "설치 확인..."
"$VENV/bin/python" - <<'EOF'
import torch
print("torch", torch.__version__, "| CUDA build", torch.version.cuda)
print("CUDA 사용 가능:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("GPU:", torch.cuda.get_device_name(0))
else:
    print("※ GPU 미검출: NVIDIA 드라이버(580 이상) 확인. CPU 모드는 ./run.sh --cpu")
EOF

if [[ $CLEAN -eq 1 ]]; then
  log "wheelhouse 삭제"
  rm -rf "$HOUSE"
fi

log "완료! 실행: ./run.sh   (브라우저에서 http://127.0.0.1:8188)"
