# Hurl Source Installer for Ubuntu

[![CI](https://github.com/KNY00/hurl-ubuntu-installer/actions/workflows/ci.yml/badge.svg)](https://github.com/KNY00/hurl-ubuntu-installer/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Ubuntu 26.04](https://img.shields.io/badge/Ubuntu-26.04_LTS-E95420?logo=ubuntu&logoColor=white)](https://ubuntu.com/)

A lightweight, zero-leftover Bash script that compiles and installs [Hurl](https://hurl.dev) (`hurl` and `hurlfmt`) from source on Ubuntu 26.04+.

## Why This Exists

Installing prebuilt Hurl binaries or `.deb` packages on newer Ubuntu releases (such as **Ubuntu 26.04**) often fails due to missing or updated shared C libraries—most notably `libxml2` ABI changes and `libcurl`/`OpenSSL` header mismatches.

This script solves that by:
1. Installing the exact native C development headers required (`libxml2-dev`, `libcurl4-openssl-dev`, `libssl-dev`, `libclang-dev`).
2. Bootstrapping a minimal, temporary Rust toolchain via `rustup` (if Cargo is not already present).
3. Compiling both `hurl` and `hurlfmt` natively against your system's exact shared libraries.
4. Purging the Rust compiler and build cache afterward so your host or Docker image stays slim.

---

## Quick Start

### One-Line Install (cURL)

```bash
curl -fsSL [https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh](https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh) | bash
```

### Clone & Run Locally

```bash
git clone [https://github.com/KNY00/hurl-ubuntu-installer.git](https://github.com/KNY00/hurl-ubuntu-installer.git)
cd hurl-ubuntu-installer
chmod +x install.sh
./install.sh
```

---

## Configuration

Customize the installation by passing environment variables before the script:

| Variable | Default | Description |
| :--- | :--- | :--- |
| `HURL_VERSION` | `8.0.1` | The specific release version of Hurl to compile. |
| `INSTALL_DIR` | `/usr/local` | Target installation prefix (binaries are placed in `$INSTALL_DIR/bin`). |
| `KEEP_RUST` | `false` | Set to `true` to prevent the script from uninstalling `rustup` after build. |
| `CLEAN_APT` | `false` | Set to `true` to clear `/var/lib/apt/lists/*` after installing packages (ideal for Docker). |

### Example with Custom Flags

```bash
curl -fsSL [https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh](https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh) | \
  HURL_VERSION="8.0.1" KEEP_RUST="true" bash
```

---

## Using in Your Own Dockerfile

You don't need to clone this repository to use it in your Docker builds. Drop this `RUN` block into any `ubuntu:26.04` Dockerfile:

```dockerfile
FROM ubuntu:26.04

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -fsSL [https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh](https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh) | CLEAN_APT=true bash
```

### Test in an Isolated Container (One-Liner)

Want to test the script right now without modifying your host system? Run it inside an ephemeral Ubuntu 26.04 container:

```bash
docker run --rm -it -v "$PWD/install.sh:/install.sh:ro" ubuntu:26.04 bash /install.sh
```

---

## Compatibility Status

| OS / Environment | Architecture | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Ubuntu 26.04 (Container / Host)** | `x86_64` / `arm64` | Tested & Working | Primary target environment. |
| **Ubuntu 24.04 LTS / 22.04 LTS** | `x86_64` / `arm64` | Compatible | Uses identical `apt` package names. |
| **Debian 12 (Bookworm) / 13 (Trixie)** | `x86_64` / `arm64` | Expected to work | Uses standard Debian/Ubuntu dev packages. |

---

## Security & Production Best Practices

### Supply Chain & Integrity
Unlike downloading unverified third-party binaries, this script builds Hurl directly from the official [crates.io](https://crates.io/crates/hurl) registry:
- **Pinned Dependency Tree:** Uses `cargo install --locked` to guarantee the exact `Cargo.lock` dependency graph tested and published by the Orange-OpenSource Hurl team.
- **Official Ubuntu Repositories:** Native C libraries (`libxml2-dev`, `libcurl4-openssl-dev`, `libssl-dev`) are fetched strictly from official Ubuntu `apt` mirrors.
- **Partial-Download Protection:** The installer script is wrapped in a `main()` execution block so `curl | bash` will never execute a partially downloaded script.

### Inspect Before Executing
If your security policy prohibits piping scripts directly from the internet into `bash`, download and inspect the script before running it:

```bash
curl -fsSLO [https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh](https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh)
less install.sh
chmod +x install.sh
./install.sh
```

### Hardened Multi-Stage Dockerfile (Recommended for Production)
While `install.sh` uninstalls the Rust compiler after building, `apt` build dependencies (`gcc`, `clang`, and `*-dev` headers) remain on the system. For production containers, use a **multi-stage build** so compilers never ship in your final runtime image:

```dockerfile
# Stage 1: Compile Hurl from source
FROM ubuntu:26.04 AS builder
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && \
    curl -fsSL [https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh](https://raw.githubusercontent.com/KNY00/hurl-ubuntu-installer/main/install.sh) | bash

# Stage 2: Minimal production runtime (no compilers or -dev headers)
FROM ubuntu:26.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    libcurl4t64 \
    libxml2 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local/bin/hurl /usr/local/bin/hurl
COPY --from=builder /usr/local/bin/hurlfmt /usr/local/bin/hurlfmt

CMD ["hurl", "--version"]
```

---

## License

Distributed under the [MIT License](LICENSE).