#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status,
# treat unset variables as an error, and fail on pipe errors.
set -euo pipefail

# Wrap the entire script in a main() function to prevent partial execution
# when piped via `curl -fsSL ... | bash`
main() {
  local hurl_version="${HURL_VERSION:-8.0.1}"
  local install_dir="${INSTALL_DIR:-/usr/local}"
  local keep_rust="${KEEP_RUST:-false}"
  local clean_apt="${CLEAN_APT:-false}"

  # Validate version format (basic sanitization against command injection)
  if [[ ! "${hurl_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then
    echo "[-] Error: Invalid HURL_VERSION format '${hurl_version}'." >&2
    exit 1
  fi

  local sudo_cmd=""
  if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
      sudo_cmd="sudo"
    else
      echo "[-] Error: Root privileges or sudo are required to install system dependencies." >&2
      exit 1
    fi
  fi

  export DEBIAN_FRONTEND=noninteractive

  echo "==> [1/5] Installing native build dependencies..."
  # APT 3.0+ (Ubuntu 26.04) strictly forbids passing arguments like -y to 'update'
  $sudo_cmd apt-get update
  $sudo_cmd apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    build-essential \
    pkg-config \
    libssl-dev \
    libcurl4-openssl-dev \
    libxml2-dev \
    libclang-dev

  local rust_was_preinstalled=true
  if ! command -v cargo >/dev/null 2>&1; then
    rust_was_preinstalled=false
    echo "==> [2/5] Installing temporary minimal Rust toolchain..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal
    # shellcheck source=/dev/null
    source "${HOME}/.cargo/env"
  else
    echo "==> [2/5] Existing Cargo installation detected, skipping rustup..."
  fi

  echo "==> [3/5] Compiling and installing Hurl v${hurl_version} into${install_dir}..."
  if [ -n "${sudo_cmd}" ] && [ ! -w "${install_dir}" ]; then
    local tmp_build_root
    tmp_build_root="$(mktemp -d)"
    # Ensure temporary build directory is cleaned up even on unexpected exit
    trap 'rm -rf "${tmp_build_root}"' EXIT
    cargo install hurl --version "${hurl_version}" --locked --root "${tmp_build_root}"
    $sudo_cmd install -m 0755 "${tmp_build_root}/bin/hurl" "${install_dir}/bin/hurl"
    rm -rf "${tmp_build_root}"
    trap - EXIT
  else
    cargo install hurl --version "${hurl_version}" --locked --root "${install_dir}"
  fi

  echo "==> [4/5] Cleaning up build artifacts..."
  if [ "${rust_was_preinstalled}" = false ] && [ "${keep_rust}" = false ]; then
    echo "    Removing temporary Rust toolchain..."
    rustup self uninstall -y
  fi

  if [ "${clean_apt}" = true ]; then
    echo "    Purging apt package lists..."
    $sudo_cmd rm -rf /var/lib/apt/lists/*
  fi

  echo "==> [5/5] Verifying installation..."
  "${install_dir}/bin/hurl" --version
  echo "[+] Hurl ${hurl_version} successfully compiled and installed!"
}

# Execute main only after the entire script has been read
main "$@"