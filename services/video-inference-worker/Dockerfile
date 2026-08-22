FROM nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 AS python-build

ARG DEBIAN_FRONTEND=noninteractive
ARG WAN_SOURCE_COMMIT=42bf4cfaa384bc21833865abc2f9e6c0e67233dc
ARG TORCH_VERSION=2.5.1
ARG TORCHVISION_VERSION=0.20.1
ARG TORCHAUDIO_VERSION=2.5.1
ARG FLASH_ATTN_VERSION=2.8.3

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        git \
        python3 \
        python3-pip \
        python3-venv \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/Wan-Video/Wan2.2.git /opt/Wan2.2 \
    && cd /opt/Wan2.2 \
    && git checkout --detach "${WAN_SOURCE_COMMIT}" \
    && git remote remove origin \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/python -m pip install --no-cache-dir \
        ninja==1.11.1.3 \
        packaging==24.2 \
        wheel==0.45.1 \
    && /opt/venv/bin/python -m pip install --no-cache-dir \
        --index-url https://download.pytorch.org/whl/cu124 \
        "torch==${TORCH_VERSION}" \
        "torchvision==${TORCHVISION_VERSION}" \
        "torchaudio==${TORCHAUDIO_VERSION}" \
    && grep -Ev '^(torch|torchvision|torchaudio|flash_attn)([<>=[:space:]]|$)' \
        requirements.txt > /tmp/wan-requirements.txt \
    && /opt/venv/bin/python -m pip install --no-cache-dir \
        -r /tmp/wan-requirements.txt \
    && /opt/venv/bin/python -m pip install --no-cache-dir --no-build-isolation \
        "flash_attn==${FLASH_ATTN_VERSION}" \
    && rm -f /tmp/wan-requirements.txt

COPY patches/wan22-release-dit-before-vae.patch /tmp/wan22-release-dit-before-vae.patch
RUN cd /opt/Wan2.2 \
    && git apply --check /tmp/wan22-release-dit-before-vae.patch \
    && git apply /tmp/wan22-release-dit-before-vae.patch \
    && rm -f /tmp/wan22-release-dit-before-vae.patch

COPY patches/wan22-tiled-vae-decode.patch /tmp/wan22-tiled-vae-decode.patch
RUN cd /opt/Wan2.2 \
    && git apply --check /tmp/wan22-tiled-vae-decode.patch \
    && git apply /tmp/wan22-tiled-vae-decode.patch \
    && python3 -m py_compile wan/modules/vae2_2.py wan/textimage2video.py \
    && rm -f /tmp/wan22-tiled-vae-decode.patch

COPY wan_init.py /opt/Wan2.2/wan/__init__.py

COPY requirements.txt /tmp/worker-requirements.txt
RUN /opt/venv/bin/python -m pip install --no-cache-dir \
        -r /tmp/worker-requirements.txt \
    && rm -f /tmp/worker-requirements.txt

FROM nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        python3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=python-build /opt/venv /opt/venv
COPY --from=python-build /opt/Wan2.2 /opt/Wan2.2

WORKDIR /app
RUN /opt/venv/bin/python -c \
    "import flash_attn, requests, torch; assert torch.version.cuda == '12.4'"
COPY worker.py run_wan.py /app/

RUN useradd --create-home --uid 10001 video-worker \
    && mkdir -p /work/output /models \
    && chown -R video-worker:video-worker /work

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/opt/venv/bin:$PATH \
    WAN_SOURCE_DIR=/opt/Wan2.2 \
    WAN_MODEL_DIR=/models/Wan2.2-TI2V-5B \
    VIDEO_OUTPUT_DIR=/work/output \
    HF_HUB_OFFLINE=1 \
    TRANSFORMERS_OFFLINE=1

USER video-worker
ENTRYPOINT ["python3", "/app/worker.py"]
