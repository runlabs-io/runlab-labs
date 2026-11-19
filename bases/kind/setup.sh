#!/bin/bash
# The kind base: kubectl, kind and helm, and the limits kind and containerd need. No cluster: a product's base makes its own.
set -euo pipefail
exec bash /root/data/kind-bootstrap.sh
