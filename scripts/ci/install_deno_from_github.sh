#!/usr/bin/env bash
set -euo pipefail

version="${DENO_VERSION:-v2.9.1}"

case "$(uname -s)" in
  Linux*) os="unknown-linux-gnu" ;;
  Darwin*) os="apple-darwin" ;;
  MINGW*|MSYS*|CYGWIN*) os="pc-windows-msvc" ;;
  *)
    echo "::error::Unsupported OS for Deno install: $(uname -s)"
    exit 1
    ;;
esac

case "$(uname -m)" in
  x86_64|amd64) arch="x86_64" ;;
  aarch64|arm64) arch="aarch64" ;;
  *)
    echo "::error::Unsupported architecture for Deno install: $(uname -m)"
    exit 1
    ;;
esac

archive="deno-${arch}-${os}.zip"
url="https://github.com/denoland/deno/releases/download/${version}/${archive}"
install_dir="${RUNNER_TOOL_CACHE:-${HOME}/.cache}/deno/${version}/${arch}-${os}"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "$install_dir"

if [ ! -x "${install_dir}/deno" ] && [ ! -x "${install_dir}/deno.exe" ]; then
  echo "Installing Deno ${version} from ${url}"
  curl -fL --retry 5 --retry-delay 5 --retry-all-errors \
    -o "${tmp_dir}/${archive}" \
    "$url"
  unzip -q -o "${tmp_dir}/${archive}" -d "$install_dir"
fi

if [ -n "${GITHUB_PATH:-}" ]; then
  echo "$install_dir" >> "$GITHUB_PATH"
fi

deno_bin="${install_dir}/deno"
if [ -x "${install_dir}/deno.exe" ]; then
  deno_bin="${install_dir}/deno.exe"
fi

"$deno_bin" --version
