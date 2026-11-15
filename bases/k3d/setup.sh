#!/bin/bash
# The Kubernetes base: k3d, MetalLB, a local registry, and a unit that restarts the stopped cluster.
set -euo pipefail
exec bash /root/data/k3d-bootstrap.sh
