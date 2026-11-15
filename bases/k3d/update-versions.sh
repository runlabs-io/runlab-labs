#!/bin/bash
# Look up the latest stable version of each tool this base installs and write them to data/versions.env, then say what changed and whether
# it looks breaking. Run it on your machine when you mean to take new versions; the build itself never looks anything up (runlab#1212).
#   ./update-versions.sh           rewrite data/versions.env
#   ./update-versions.sh --check   only show what would change
# Then review `git diff`, decide on `version:` in config.yaml (raise it for a change that breaks the labs on this base), and commit.
# GITHUB_TOKEN, if set, is used for the GitHub API (it has a low limit without one).
set -euo pipefail
here=$(dirname "$(readlink -f "$0")")
env_file=$here/data/versions.env
check=0
[ "${1:-}" = "--check" ] && check=1
api() { curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "$1"; }
declare -A new
new[KUBECTL_VERSION]=$(curl -fsSL https://dl.k8s.io/release/stable.txt)
new[K3D_VERSION]=$(api https://api.github.com/repos/k3d-io/k3d/releases/latest | jq -r .tag_name)
new[HELM_VERSION]=$(api https://api.github.com/repos/helm/helm/releases/latest | jq -r .tag_name)
# MetalLB: the newest plain vX.Y.Z git tag. GitHub's "latest release" is a chart tag now, and the releases list lags a version.
new[METALLB_VERSION]=$(api "https://api.github.com/repos/metallb/metallb/tags?per_page=60" | jq -r '.[].name' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
for k in "${!new[@]}"; do
  [ -n "${new[$k]}" ] && [ "${new[$k]}" != null ] || { echo "update-versions: could not find the latest $k" >&2; exit 1; }
done
breaking=0
changed=0
for k in KUBECTL_VERSION K3D_VERSION HELM_VERSION METALLB_VERSION; do
  old=$(sed -n "s/^$k=//p" "$env_file")
  if [ "$old" = "${new[$k]}" ]; then
    printf '  %-17s %s (unchanged)\n' "$k" "$old"
    continue
  fi
  changed=1
  # v1.37.2 -> major.minor: a change of either is a new line of the tool, which can break a lab built on the old one.
  line() { echo "$1" | sed -E 's/^v?([0-9]+\.[0-9]+).*/\1/'; }
  note="patch or build only"
  if [ "$(line "$old")" != "$(line "${new[$k]}")" ]; then note="NEW MAJOR OR MINOR LINE"; breaking=1; fi
  printf '  %-17s %s -> %s   (%s)\n' "$k" "$old" "${new[$k]}" "$note"
  [ "$check" = 1 ] || sed -i "s/^$k=.*/$k=${new[$k]}/" "$env_file"
done
current=$(sed -n 's/^image: *//p' "$here/data/cluster-config.yaml")
stable=$(curl -fsSL -o /dev/null -w '%{url_effective}' https://update.k3s.io/v1-release/channels/stable | sed 's#.*/##; s/+/-/')
echo "  k3s image          $current   (the stable channel is rancher/k3s:$stable; it is not changed here: it was vetted, so edit data/cluster-config.yaml yourself)"
echo
if [ "$changed" = 0 ]; then
  echo "nothing to take: every tool is already at its latest stable."
elif [ "$check" = 1 ]; then
  echo "this is what would change; run without --check to write it."
else
  echo "data/versions.env is updated. Review the diff."
  if [ "$breaking" = 1 ]; then
    echo "A tool moved to a new major or minor line: consider raising version: in config.yaml (a lab on this base may need to change)."
  else
    echo "Only patch-level changes: an addition, so version: can stay."
  fi
fi
