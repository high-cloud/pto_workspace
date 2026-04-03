#!/usr/bin/env bash
# Compatibility shim. Prefer: source scripts/env.sh

_MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${_MODULES_DIR}/../scripts/env.sh" "$@"
