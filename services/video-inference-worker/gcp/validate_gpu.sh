#!/usr/bin/env bash
set -Eeuo pipefail

if [[ $# -ne 1 ]] || [[ "$1" != *@sha256:* ]]; then
  echo "usage: validate_gpu.sh <immutable-container-image-digest>" >&2
  exit 2
fi

readonly CONTAINER_IMAGE="$1"
readonly MODEL_DIR="/srv/models/Wan2.2-TI2V-5B"
readonly VALIDATION_DIR="/srv/models/validation"
readonly PROMPT_FILE="${VALIDATION_DIR}/prompt.txt"
readonly OUTPUT_FILE="${VALIDATION_DIR}/wan22-l4-validation.mp4"

if [[ ! -f "${MODEL_DIR}/.omocha-model-revision" ]]; then
  echo "Pinned model revision marker is missing" >&2
  exit 1
fi

install -d -o 10001 -g 10001 -m 0700 "${VALIDATION_DIR}"
printf '%s\n' \
  'A tiny red wind-up robot walks across a clean wooden desk in warm morning light, static camera, realistic product video.' \
  > "${PROMPT_FILE}"
chown 10001:10001 "${PROMPT_FILE}"
chmod 0600 "${PROMPT_FILE}"
rm -f "${OUTPUT_FILE}"

started_epoch="$(date +%s)"
docker run --rm \
  --name wan22-l4-validation \
  --gpus all \
  --env HF_HUB_OFFLINE=1 \
  --env TRANSFORMERS_OFFLINE=1 \
  --env WAN_SOURCE_DIR=/opt/Wan2.2 \
  --env VIDEO_PROMPT_FILE=/validation/prompt.txt \
  --mount "type=bind,src=${MODEL_DIR},dst=/models/Wan2.2-TI2V-5B,readonly" \
  --mount "type=bind,src=${VALIDATION_DIR},dst=/validation" \
  --entrypoint python3 \
  "${CONTAINER_IMAGE}" \
  /app/run_wan.py \
  --task ti2v-5B \
  --size '1280*704' \
  --frame_num 121 \
  --ckpt_dir /models/Wan2.2-TI2V-5B \
  --offload_model True \
  --convert_model_dtype \
  --t5_cpu \
  --base_seed 20260820 \
  --save_file /validation/wan22-l4-validation.mp4

elapsed_seconds="$(( $(date +%s) - started_epoch ))"
rm -f "${PROMPT_FILE}"

docker run --rm \
  --mount "type=bind,src=${VALIDATION_DIR},dst=/validation,readonly" \
  --entrypoint ffprobe \
  "${CONTAINER_IMAGE}" \
  -v error \
  -select_streams v:0 \
  -show_entries stream=codec_name,width,height,r_frame_rate,nb_frames,duration \
  -show_entries format=size,duration \
  -of json \
  /validation/wan22-l4-validation.mp4

printf 'validation_elapsed_seconds=%s\n' "${elapsed_seconds}"
