#!/usr/bin/env bash
set -Eeuo pipefail

readonly METADATA_ROOT="http://metadata.google.internal/computeMetadata/v1"
readonly METADATA_HEADER="Metadata-Flavor: Google"
readonly MODEL_DEVICE="/dev/disk/by-id/google-video-model-cache"
readonly MODEL_MOUNT="/srv/models"
readonly MODEL_DIR="${MODEL_MOUNT}/Wan2.2-TI2V-5B"
readonly STATE_DIR="/var/lib/video-worker"
readonly GPU_READY_ATTEMPTS=24
readonly GPU_READY_RETRY_SECONDS=5

exec > >(logger --tag video-gpu-startup) 2>&1

# The unit is intentionally kept disabled between boots. A unit left enabled by
# an older startup script can otherwise claim a paid job while Docker, the model
# image, and the GPU runtime are still being provisioned on this boot.
systemctl disable --now video-worker.service || true

metadata() {
  curl --fail --silent --show-error \
    --header "${METADATA_HEADER}" \
    "${METADATA_ROOT}/$1"
}

attribute() {
  metadata "instance/attributes/$1"
}

readonly PROJECT_ID="$(metadata project/project-id)"
readonly CONTAINER_IMAGE="$(attribute video-container-image)"
readonly MODEL_REVISION="$(attribute video-model-revision)"
readonly WORKER_URL="$(attribute video-worker-url)"
readonly WORKER_ID="$(attribute video-worker-id)"
readonly WORKER_ENABLED="$(attribute video-worker-enabled)"
readonly AUTO_STOP_MINUTES="$(attribute video-auto-stop-minutes)"
readonly IDLE_EXIT_SECONDS="$(
  attribute video-worker-idle-exit-seconds 2>/dev/null || printf '600'
)"
readonly REGISTRY_HOST="${CONTAINER_IMAGE%%/*}"
readonly DOCKER_AUTH_DIR="/run/video-docker-auth"

if [[ "${AUTO_STOP_MINUTES}" =~ ^[0-9]+$ ]] && \
   (( AUTO_STOP_MINUTES >= 15 && AUTO_STOP_MINUTES <= 1440 )); then
  shutdown --poweroff "+${AUTO_STOP_MINUTES}"
else
  echo "video-auto-stop-minutes must be between 15 and 1440" >&2
  exit 1
fi

mkdir -p "${MODEL_MOUNT}" "${STATE_DIR}"

if [[ ! -b "${MODEL_DEVICE}" ]]; then
  echo "Dedicated model disk is missing: ${MODEL_DEVICE}" >&2
  exit 1
fi

filesystem_type="$(blkid -o value -s TYPE "${MODEL_DEVICE}" || true)"
if [[ -z "${filesystem_type}" ]]; then
  mkfs.ext4 -F -m 0 -L video-models "${MODEL_DEVICE}"
elif [[ "${filesystem_type}" != "ext4" ]]; then
  echo "Unexpected model disk filesystem: ${filesystem_type}" >&2
  exit 1
fi

if ! grep -qF "${MODEL_DEVICE} ${MODEL_MOUNT} ext4" /etc/fstab; then
  printf '%s %s ext4 defaults,nofail 0 2\n' \
    "${MODEL_DEVICE}" "${MODEL_MOUNT}" >> /etc/fstab
fi
mountpoint --quiet "${MODEL_MOUNT}" || mount "${MODEL_MOUNT}"
chmod 0755 "${MODEL_MOUNT}"

if ! command -v docker >/dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends docker.io
  rm -rf /var/lib/apt/lists/*
fi

if ! command -v nvidia-ctk >/dev/null 2>&1; then
  echo "NVIDIA Container Toolkit is missing from the GPU host image" >&2
  exit 1
fi
nvidia-ctk runtime configure --runtime=docker
systemctl enable --now docker
systemctl restart docker
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader

install -d -m 0700 "${DOCKER_AUTH_DIR}"
export DOCKER_CONFIG="${DOCKER_AUTH_DIR}"
access_token="$(gcloud auth print-access-token --quiet)"
printf '%s' "${access_token}" | docker login \
  --username oauth2accesstoken \
  --password-stdin \
  "https://${REGISTRY_HOST}" >/dev/null
unset access_token
docker pull "${CONTAINER_IMAGE}"
docker logout "${REGISTRY_HOST}" >/dev/null 2>&1 || true
find "${DOCKER_AUTH_DIR}" -type f -delete
rmdir "${DOCKER_AUTH_DIR}" || true
unset DOCKER_CONFIG

revision_marker="${MODEL_DIR}/.omocha-model-revision"
if [[ ! -f "${revision_marker}" ]] || \
   [[ "$(cat "${revision_marker}")" != "${MODEL_REVISION}" ]]; then
  mkdir -p "${MODEL_DIR}"
  docker run --rm \
    --user root \
    --env HF_HUB_OFFLINE=0 \
    --env TRANSFORMERS_OFFLINE=0 \
    --mount "type=bind,src=${MODEL_MOUNT},dst=/models" \
    --entrypoint python3 \
    "${CONTAINER_IMAGE}" \
    -c "from huggingface_hub import snapshot_download; snapshot_download(repo_id='Wan-AI/Wan2.2-TI2V-5B', revision='${MODEL_REVISION}', local_dir='/models/Wan2.2-TI2V-5B')"
  printf '%s\n' "${MODEL_REVISION}" > "${revision_marker}"
fi

gpu_ready=false
for gpu_attempt in $(seq 1 "${GPU_READY_ATTEMPTS}"); do
  if docker run --rm \
    --gpus all \
    --mount "type=bind,src=${MODEL_DIR},dst=/models/Wan2.2-TI2V-5B,readonly" \
    --entrypoint python3 \
    "${CONTAINER_IMAGE}" \
    -c "import flash_attn, torch; assert torch.cuda.is_available(); print(torch.cuda.get_device_name(0))"; then
    gpu_ready=true
    break
  fi

  echo "GPU container runtime is not ready (attempt ${gpu_attempt}/${GPU_READY_ATTEMPTS}); retrying in ${GPU_READY_RETRY_SECONDS}s" >&2
  sleep "${GPU_READY_RETRY_SECONDS}"
done

if [[ "${gpu_ready}" != "true" ]]; then
  echo "GPU container runtime did not become ready after ${GPU_READY_ATTEMPTS} attempts" >&2
  exit 1
fi

install -m 0755 /dev/stdin /usr/local/sbin/run-video-worker <<'WORKER_SCRIPT'
#!/usr/bin/env bash
set -Eeuo pipefail

readonly token_directory="/run/video-worker-secrets"
readonly token_file="${token_directory}/video-worker-token"

cleanup_worker_secret() {
  rm -f "${token_file}"
  rmdir "${token_directory}" 2>/dev/null || true
}
trap cleanup_worker_secret EXIT

install -d -m 0700 "${token_directory}"
gcloud secrets versions access latest \
  --secret=video-worker-token \
  --project=mighty-link-ai-connect \
  --quiet | tr -d '\r\n' > "${token_file}"
if ! LC_ALL=C grep -Eq '^[A-Za-z0-9._~-]{32,256}$' "${token_file}"; then
  echo "video-worker-token has an invalid format" >&2
  exit 1
fi
chown 10001:10001 "${token_file}"
chmod 0400 "${token_file}"

set +e
docker run --rm \
  --name video-worker \
  --gpus all \
  --env "VIDEO_WORKER_URL=${VIDEO_WORKER_URL}" \
  --env VIDEO_WORKER_TOKEN_FILE=/run/secrets/video-worker-token \
  --env "VIDEO_WORKER_ID=${VIDEO_WORKER_ID}" \
  --env "VIDEO_IDLE_EXIT_SECONDS=${VIDEO_IDLE_EXIT_SECONDS}" \
  --mount "type=bind,src=${token_file},dst=/run/secrets/video-worker-token,readonly" \
  --mount "type=bind,src=/srv/models/Wan2.2-TI2V-5B,dst=/models/Wan2.2-TI2V-5B,readonly" \
  "${VIDEO_CONTAINER_IMAGE}"
exit_code=$?
set -e

if [[ ${exit_code} -eq 0 ]]; then
  shutdown --poweroff now
fi
exit "${exit_code}"
WORKER_SCRIPT

install -m 0644 /dev/stdin /etc/systemd/system/video-worker.service <<EOF
[Unit]
Description=First-party Wan2.2 video generation worker
After=docker.service network-online.target
Wants=network-online.target
Requires=docker.service

[Service]
Type=simple
Environment=VIDEO_WORKER_URL=${WORKER_URL}
Environment=VIDEO_WORKER_ID=${WORKER_ID}
Environment=VIDEO_CONTAINER_IMAGE=${CONTAINER_IMAGE}
Environment=VIDEO_IDLE_EXIT_SECONDS=${IDLE_EXIT_SECONDS}
ExecStart=/usr/local/sbin/run-video-worker
ExecStop=/usr/bin/docker stop --time 30 video-worker
Restart=on-failure
RestartSec=15
TimeoutStopSec=45

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl disable video-worker.service || true
if [[ "${WORKER_ENABLED}" == "true" ]]; then
  systemctl start video-worker.service
else
  systemctl stop video-worker.service || true
fi

printf '%s\n' "ready" > "${STATE_DIR}/status"
echo "GPU worker host provisioning completed."
