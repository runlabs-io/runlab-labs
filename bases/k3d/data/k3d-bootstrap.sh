#!/bin/bash
# The shared Kubernetes bootstrap for the KubeCon labs: k3d, a MetalLB pool, a local registry, and a boot unit that
# restarts the stopped cluster. Every lab that needs a cluster carries this file UNCHANGED (the labs check that they are identical).
# Runs as root on the build VM after the common setup. /root/data (this directory) is already on the disk.
# What "latest" resolves to is written to /root/versions.txt.
set -euo pipefail
trap '' HUP

export DEBIAN_FRONTEND=noninteractive
export HOME=/root
here=$(dirname "$(readlink -f "$0")")
cluster=my-k8s-cluster
versions=/root/versions.txt
: > "$versions"
note() { echo "$1" | tee -a "$versions"; }

echo "k3d bootstrap starting"

install_bin() {
  curl -fL --retry 3 -o "$2" "$1"
  chmod 755 "$2"
}

# The tools are pinned in versions.env, so a rebuild of this version is this version again (a foundation switch or a lost build rebuilds it).
# New versions arrive when the author runs ../update-versions.sh and commits the result: an addition keeps `version:` in config.yaml, a change
# that breaks a lab on this base raises it (runlab#1212).
. "$here/versions.env"
kubectl_version=$KUBECTL_VERSION
install_bin "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl" /usr/local/bin/kubectl
k3d_version=$K3D_VERSION
install_bin "https://github.com/k3d-io/k3d/releases/download/${k3d_version}/k3d-linux-amd64" /usr/local/bin/k3d
helm_version=$HELM_VERSION
curl -fL --retry 3 -o /tmp/helm.tgz "https://get.helm.sh/helm-${helm_version}-linux-amd64.tar.gz"
tar -xzf /tmp/helm.tgz -C /tmp
install -m 755 /tmp/linux-amd64/helm /usr/local/bin/helm
rm -rf /tmp/helm.tgz /tmp/linux-amd64
metallb_version=$METALLB_VERSION
k3s_image=$(sed -n 's/^image: *//p' "$here/cluster-config.yaml")
note "kubectl ${kubectl_version}"
note "k3d ${k3d_version}"
note "helm ${helm_version}"
note "metallb ${metallb_version}"
note "k3s image ${k3s_image}"

kubectl completion bash > /usr/share/bash-completion/completions/kubectl
k3d completion bash > /usr/share/bash-completion/completions/k3d
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

# k3s and containerd watch a lot of files. The image defaults are too small.
cat > /etc/sysctl.d/99-k3d.conf << 'EOF2'
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 512
EOF2
sysctl --system >/dev/null

# Firecracker has no /dev/kmsg. k3s refuses to start until the link exists.
if [ ! -e /dev/kmsg ]; then
  ln -s /dev/console /dev/kmsg
fi
# The docker service returns before dockerd is listening.
i=0
while [ "$i" -lt 60 ]; do
  docker info >/dev/null 2>&1 && break
  i=$((i + 1))
  sleep 1
done
docker info >/dev/null

k3d cluster create --config "$here/cluster-config.yaml"
# Docker gives out addresses on the cluster network in the order containers start. The registry is the one container
# still running when the VM shuts down, so Docker would start it first at the next boot, it would take the address the
# server had, and k3s would stop because the address it remembers is gone (runlab#837). Docker must not start it:
# k3d-lab-start starts the cluster first and the registry after.
docker update --restart=no k3d-myreg >/dev/null
kubectl wait --for=condition=Ready node --all --timeout=180s

# MetalLB gives a Gateway an address that works inside the VM. ServiceLB (k3s) stays on beside it.
kubectl apply -f "https://raw.githubusercontent.com/metallb/metallb/${metallb_version}/config/manifests/metallb-native.yaml"
# The deployment and daemonset exist as soon as apply returns. A pod wait exits immediately when the pods have not been created yet.
kubectl -n metallb-system rollout status deployment/controller --timeout=300s
kubectl -n metallb-system rollout status daemonset/speaker --timeout=300s
gateway_ip=$(docker network inspect "k3d-${cluster}" | jq -r '[.[0].IPAM.Config[].Gateway | select(test("^[0-9.]+$"))][0]')
prefix=${gateway_ip%.*}
kubectl apply -f - << EOT
---
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: k3d-pool
  namespace: metallb-system
spec:
  addresses:
  - ${prefix}.200-${prefix}.250
  autoAssign: true
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: k3d-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - k3d-pool
EOT

# pull-image IMAGE: docker pull, tried up to three times. A registry now and then answers with a passing 5xx (a 522
# from cr.agentgateway.dev ended a lab build once), and one such answer should not end a build. Labs call it from product.sh.
cat > /usr/local/bin/pull-image << 'EOF2'
#!/bin/sh
attempt=1
while [ "$attempt" -le 3 ]; do
  if docker pull "$1"; then
    exit 0
  fi
  echo "pull-image: try $attempt of $1 failed" >&2
  attempt=$((attempt + 1))
  sleep $((attempt * 5))
done
exit 1
EOF2
chmod 755 /usr/local/bin/pull-image

# The cluster is stopped in the image. Booting the microVM starts it again, and ssh waits for that so the
# lesson opens with kubectl already working.
cat > /usr/local/sbin/k3d-lab-start << 'EOF2'
#!/bin/sh
set -eu
if [ ! -e /dev/kmsg ]; then
  ln -s /dev/console /dev/kmsg
fi
i=0
while [ "$i" -lt 60 ]; do
  if docker info >/dev/null 2>&1; then
    break
  fi
  i=$((i + 1))
  sleep 1
done
if ! docker info >/dev/null 2>&1; then
  echo "dockerd did not start" >&2
  exit 1
fi
# The server starts first, so it gets the address it had when the cluster was built (see the registry note above).
# k3d cluster start waits for k3s to say it is up, and has no time limit by default. If k3s ever exits just after it
# starts and Docker restarts it, the wait never ends, and sshd, which waits for this unit, never opens (runlab#837).
# So the wait is bounded; a start that does not finish records what the server was doing, restarts the server and
# tries again, and after three tries fails the unit with that on the console.
attempt=1
while [ "$attempt" -le 3 ]; do
  if k3d cluster start my-k8s-cluster --wait --timeout 90s; then
    # The registry belongs to the cluster but k3d cluster stop leaves it running; start it now that the server has its address.
    docker start k3d-myreg >/dev/null 2>&1 || true
    exit 0
  fi
  echo "k3d-lab-start: try $attempt did not bring the cluster up; the server said:" >&2
  docker logs --tail 40 k3d-my-k8s-cluster-server-0 >&2 || true
  {
    echo "=== $(date -u +%T) try $attempt failed"
    docker inspect -f 'status={{.State.Status}} exit={{.State.ExitCode}} oom={{.State.OOMKilled}} started={{.State.StartedAt}} finished={{.State.FinishedAt}}' k3d-my-k8s-cluster-server-0
    docker logs --tail 40 k3d-my-k8s-cluster-server-0 2>&1
  } >> /root/k3d-start-failures.log 2>&1 || true
  docker restart k3d-my-k8s-cluster-server-0 >/dev/null 2>&1 || true
  attempt=$((attempt + 1))
done
echo "k3d-lab-start: the cluster did not come up in 3 tries" >&2
exit 1
EOF2
chmod 755 /usr/local/sbin/k3d-lab-start

if systemctl cat ssh.service >/dev/null 2>&1; then
  ssh_unit=ssh.service
elif systemctl cat sshd.service >/dev/null 2>&1; then
  ssh_unit=sshd.service
else
  echo "no ssh service on this image" >&2
  exit 1
fi
cat > /etc/systemd/system/k3d-cluster.service << EOF2
[Unit]
Description=Start the lab cluster
After=docker.service
Requires=docker.service
Before=${ssh_unit}

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/k3d-lab-start

[Install]
WantedBy=multi-user.target
EOF2
mkdir -p "/etc/systemd/system/${ssh_unit}.d"
cat > "/etc/systemd/system/${ssh_unit}.d/k3d.conf" << EOF2
[Unit]
After=k3d-cluster.service
Requires=k3d-cluster.service
EOF2
systemctl daemon-reload
systemctl enable k3d-cluster.service
systemctl enable "$ssh_unit"
systemctl disable ssh.socket || true

# A lab that specializes the base (fetches its images, say) says so in product.sh, which runs here, with the cluster up.
if [ -f "$here/product.sh" ]; then
  bash "$here/product.sh"
fi

k3d cluster stop "$cluster"
echo "k3d bootstrap done"
