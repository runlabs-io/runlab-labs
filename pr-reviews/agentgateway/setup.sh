#!/bin/bash
# pr-review: the tools agentgateway's development setup needs for standalone mode (Rust at the version the project pins,
# Node and pnpm for the UI), a clone of main, and the build caches warmed by one build of main.
# Runs as root after the common setup.
set -euo pipefail
trap '' HUP

export DEBIAN_FRONTEND=noninteractive
export HOME=/root

NODE_VERSION=24.22.1

echo "pr-review setup starting"

apt-get update
apt-get install -y jq git make build-essential pkg-config cmake clang curl ca-certificates xz-utils protobuf-compiler

fetch() { curl -fL --retry 3 -o "$1" "$2"; }

# Node, at the version ui/.nvmrc names; corepack (bundled with it) provides the pinned pnpm.
fetch /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64.tar.xz"
tar -C /usr/local --strip-components=1 -xJf /tmp/node.tar.xz
rm -f /tmp/node.tar.xz
corepack enable

# The lab's data files (the two-row layout) go to root's home.
cp -r /root/data/. /root/ 2>/dev/null || true
chown root:root /root
chmod 700 /root

# main, as of this build, with its full history (about 70 MiB). trylab gives the guest the pull request's commits as a git
# bundle of what this clone lacks (runlab#1227), and a bundle needs the commits it was cut from: a shallow clone would refuse it.
git clone https://github.com/agentgateway/agentgateway /root/agentgateway
cd /root/agentgateway

# Rust, at the channel rust-toolchain.toml pins.
channel=$(awk -F'"' '/^channel =/ {print $2}' rust-toolchain.toml)
fetch /tmp/rustup-init.sh https://sh.rustup.rs
sh /tmp/rustup-init.sh -y --profile minimal --default-toolchain "$channel" -c clippy -c rustfmt
rm -f /tmp/rustup-init.sh
echo '. /root/.cargo/env' >> /root/.bashrc
. /root/.cargo/env

# One build of main warms the cargo registry, the dependencies' build products and the UI's pnpm store.
# The quick-release profile is the project's own for incremental development; the UI is embedded by --features ui.
(cd ui && pnpm install --frozen-lockfile && pnpm build)
cargo build --profile quick-release --features ui

echo "pr-review setup done"
