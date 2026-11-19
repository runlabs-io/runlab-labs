#!/bin/bash
# The shared kind bootstrap: kubectl, kind and helm, shell completions and the `k` alias, and the inotify limits kind and containerd need.
# There is no cluster in the image: a product's base creates its own (its configuration, registry and add-ons differ), and Docker is on the
# default disk. Runs as root on the build VM after the common setup. /root/data (this directory) is already on the disk.
# What the tools resolved to is written to /root/versions.txt.
set -euo pipefail
trap '' HUP

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
here=$(dirname "$(readlink -f "$0")")
versions=/root/versions.txt
: > "$versions"
note() { echo "$1" | tee -a "$versions"; }

echo "kind bootstrap starting"

install_bin() {
  curl -fL --retry 3 --retry-all-errors -o "$2" "$1"
  chmod 755 "$2"
}

# The tools are pinned in versions.env, so a rebuild of this version is this version again (a foundation switch or a lost build rebuilds it).
# New versions arrive when the author runs ../update-versions.sh and commits the result: an addition keeps `version:` in config.yaml, a change
# that breaks a lab on this base raises it (runlab#1212).
. "$here/versions.env"
install_bin "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" /usr/local/bin/kubectl
install_bin "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64" /usr/local/bin/kind
curl -fL --retry 3 --retry-all-errors -o /tmp/helm.tgz "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
tar -xzf /tmp/helm.tgz -C /tmp
install -m 755 /tmp/linux-amd64/helm /usr/local/bin/helm
rm -rf /tmp/helm.tgz /tmp/linux-amd64
note "kubectl ${KUBECTL_VERSION}"
note "kind ${KIND_VERSION}"
note "helm ${HELM_VERSION}"

kubectl completion bash > /usr/share/bash-completion/completions/kubectl
kind completion bash > /usr/share/bash-completion/completions/kind
helm completion bash > /usr/share/bash-completion/completions/helm
cat >> /root/.bashrc << 'RC'

alias k=kubectl
# The completion file defines __start_kubectl and binds it to kubectl.
# bash-completion loads that file only when completing the kubectl command,
# so the alias needs the function loaded itself.
if [ -f /usr/share/bash-completion/completions/kubectl ]; then
  . /usr/share/bash-completion/completions/kubectl
  complete -o default -F __start_kubectl k
fi
RC

# kind and containerd watch a lot of files. The image defaults are too small.
cat > /etc/sysctl.d/99-kind.conf << 'EOF2'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF2
sysctl --system >/dev/null

echo "kind bootstrap done"
