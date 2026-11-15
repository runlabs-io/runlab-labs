#!/bin/bash
# The platform runs this in the guest when the base's disk is booted for a lab to be built on it, and starts the lab's
# setup.sh when it ends (runlab#853). The cluster was started a moment ago. Its API server answers before the kubelet
# has looked at the pods, and the status saved before the cluster stopped still says every Deployment is available,
# so a rollout status passes at once. The base is ready when the pods themselves are all ready and none has restarted
# for 30 seconds.
set -eu
kubectl wait --for=condition=Ready node --all --timeout=180s
last=-1
stable=0
for _ in $(seq 1 90); do
  state=$(kubectl get pods -A --field-selector=status.phase!=Succeeded --no-headers 2>/dev/null |
    awk '{split($3, r, "/"); if (r[1] != r[2] || $4 != "Running") bad++; restarts += $5; n++} END {print n + 0, bad + 0, restarts + 0}') || state="0 1 0"
  set -- $state
  if [ "$1" -gt 0 ] && [ "$2" -eq 0 ] && [ "$3" -eq "$last" ]; then
    stable=$((stable + 1))
  else
    stable=0
  fi
  last=$3
  if [ "$stable" -ge 6 ]; then
    exit 0
  fi
  sleep 5
done
echo "the pods did not settle" >&2
kubectl get pods -A >&2 || true
exit 1
