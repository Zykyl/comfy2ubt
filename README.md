# comfy2ubt — 인터넷 없는 Ubuntu 24.04 에 ComfyUI 설치하기

이 저장소 하나만 복사하면 **인터넷 연결 없이** ComfyUI 를 설치할 수 있습니다.
ComfyUI 소스, 필요한 Python 패키지(wheel) 전부, Python 3.12 venv 용 `.deb` 가 들어 있습니다.

| 항목 | 내용 |
|---|---|
| 대상 OS | Ubuntu 24.04 LTS (x86_64) |
| Python | 3.12 (Ubuntu 24.04 기본 탑재) |
| ComfyUI | v0.37.0 (`COMFYUI_COMMIT.txt` 참조) |
| PyTorch | 2.14.0 + CUDA 13.0 (torchvision 0.29.0, triton 3.8.0) |
| GPU 요구사항 | NVIDIA GPU + **NVIDIA 드라이버 580 이상** (`nvidia-smi` 로 확인) |
| 용량 | 저장소 약 3.7GB, 설치 후 venv 약 7GB 추가 |

## 1. 인터넷 되는 PC 에서 받기

```bash
git clone https://github.com/zykyl/comfy2ubt.git
# 또는 GitHub 에서 ZIP 다운로드
```

받은 폴더를 USB 등으로 오프라인 PC 에 복사합니다.

## 2. 오프라인 PC 에서 설치

```bash
cd comfy2ubt
./install.sh          # 설치 후 ~3.7GB 임시 파일을 지우려면: ./install.sh --clean
```

설치 스크립트가 하는 일:
1. `python3.12` 가 없으면 `packages/debs/*.deb` 설치 (sudo 필요)
2. 90MB 단위로 쪼갠 대용량 wheel(`packages/split/`) 을 다시 합치고 SHA256 검증
3. uv wheel 안의 `uv` 바이너리를 꺼내 `./venv` 가상환경 생성
4. `requirements-lock.txt` 의 버전 고정 패키지를 `--offline --no-index` 로 설치
5. `torch.cuda.is_available()` 로 GPU 인식 확인

sudo 권한이 필요한 것은 1번(Python 이 없을 때)뿐입니다.

## 3. 실행

```bash
./run.sh                       # http://127.0.0.1:8188
./run.sh --listen 0.0.0.0      # 다른 PC 에서 접속 허용
./run.sh --cpu                 # GPU 없이 CPU 로 실행 (느림)
./run.sh --enable-manager      # ComfyUI-Manager 활성화 (오프라인에서는 기능 제한)
```

`run.sh` 는 인터넷 접속을 시도하지 않도록 `--disable-api-nodes`, `HF_HUB_OFFLINE=1` 을 기본으로 켭니다.

## 4. 모델 파일

모델(checkpoint 등)은 용량 때문에 포함하지 않았습니다. 인터넷 되는 곳에서 받아 아래 위치에 넣으세요.

| 종류 | 위치 |
|---|---|
| Checkpoint (SD1.5/SDXL 등) | `ComfyUI/models/checkpoints/` |
| LoRA | `ComfyUI/models/loras/` |
| VAE | `ComfyUI/models/vae/` |
| Diffusion 모델 (Flux 등) | `ComfyUI/models/diffusion_models/` |
| Text encoder | `ComfyUI/models/text_encoders/` |

## 저장소 구성

```
ComfyUI/                 ComfyUI 소스 (git 이력 제외)
packages/wheels/         Python wheel (95MB 미만)
packages/split/          95MB 이상 wheel 을 90MB 조각으로 분할 (GitHub 100MB 제한 때문)
packages/debs/           python3.12, python3.12-venv 등 .deb (noble-security)
packages/SHA256SUMS      원본 wheel/deb 체크섬
requirements-lock.txt    전체 의존성 버전 고정 목록
install.sh / run.sh      설치 / 실행 스크립트
```

## 문제 해결

- **`CUDA 사용 가능: False`** — `nvidia-smi` 로 드라이버 버전을 확인하세요. CUDA 13 빌드라서 580 이상이 필요합니다.
  드라이버를 올릴 수 없으면 `./run.sh --cpu` 로 실행하거나, 다른 CUDA 버전의 torch wheel 로 교체해야 합니다.
- **체크섬 불일치** — 복사 도중 파일이 손상됐습니다. 저장소를 다시 복사하세요.
- **패키지 추가 설치** — venv 의 pip 는 `packages/wheelhouse` 만 보도록 설정돼 있어, 없는 패키지는 설치되지 않습니다.
  인터넷 되는 PC 에서 `pip download` 로 받아 와서 `./venv/bin/pip install 파일.whl` 로 설치하세요.
