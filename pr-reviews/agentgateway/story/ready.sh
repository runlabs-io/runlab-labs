#!/bin/bash
# The snapshot is taken when the toolchains and the warm build are in place: nothing runs in the guest, so this checks what
# the lesson depends on.
set -eu
. /root/.cargo/env
cargo --version
node --version
test -x /root/agentgateway/target/quick-release/agentgateway
