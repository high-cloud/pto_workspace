#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# PyPTO-Lib workspace environment activation
# Preferred usage: source scripts/env.sh
# Optional override: PTO_CONDA_ENV_NAME=<env_name> source scripts/env.sh
# ---------------------------------------------------------------------------
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODULES_DIR="${ROOT_DIR}/modules"
DEFAULT_CONDA_ENV_NAME="pypto-lib"
REQUESTED_CONDA_ENV_NAME="${1:-${PTO_CONDA_ENV_NAME:-}}"
PTOAS_ROOT_DEFAULT="${HOME}/.local/ptoas/v0.19"
PTOAS_ROOT="${PTOAS_ROOT:-$PTOAS_ROOT_DEFAULT}"
SIMPLER_ROOT="${SIMPLER_ROOT:-${MODULES_DIR}/simpler}"
PYPTO_LIB_ROOT="${MODULES_DIR}/pypto-lib"

CONDA_BASE=""
if [[ -n "${CONDA_EXE:-}" ]]; then
    CONDA_BASE="$(cd "$(dirname "$CONDA_EXE")/.." && pwd)"
elif command -v conda >/dev/null 2>&1; then
    CONDA_BIN="$(command -v conda)"
    CONDA_BASE="$(cd "$(dirname "$CONDA_BIN")/.." && pwd)"
fi

if [[ -z "$CONDA_BASE" || ! -f "$CONDA_BASE/etc/profile.d/conda.sh" ]]; then
    echo "[ERROR] Unable to locate conda.sh. Ensure conda is installed and on PATH."
    return 1 2>/dev/null || exit 1
fi

# shellcheck disable=SC1091
source "$CONDA_BASE/etc/profile.d/conda.sh"

ACTIVE_CONDA_ENV="${CONDA_DEFAULT_ENV:-}"
if [[ -n "$ACTIVE_CONDA_ENV" ]]; then
    CONDA_ENV_NAME="$ACTIVE_CONDA_ENV"
elif [[ -n "$REQUESTED_CONDA_ENV_NAME" ]]; then
    if ! conda activate "$REQUESTED_CONDA_ENV_NAME" 2>/dev/null; then
        echo "[ERROR] Conda environment '$REQUESTED_CONDA_ENV_NAME' does not exist."
        echo "        Create it first or activate the correct environment manually."
        return 1 2>/dev/null || exit 1
    fi
    CONDA_ENV_NAME="$REQUESTED_CONDA_ENV_NAME"
else
    if ! conda activate "$DEFAULT_CONDA_ENV_NAME" 2>/dev/null; then
        echo "[ERROR] No active conda environment detected, and default env '$DEFAULT_CONDA_ENV_NAME' was not found."
        echo "        Either:"
        echo "          1. conda activate <your-env> && source scripts/env.sh"
        echo "          2. PTO_CONDA_ENV_NAME=<your-env> source scripts/env.sh"
        echo "          3. conda create -n $DEFAULT_CONDA_ENV_NAME python=3.10 -y"
        return 1 2>/dev/null || exit 1
    fi
    CONDA_ENV_NAME="$DEFAULT_CONDA_ENV_NAME"
fi

# simpler's sim toolchain expects gcc-15/g++-15; provide env-local shims if needed.
if ! command -v g++-15 >/dev/null 2>&1; then
    GXX_CANDIDATE=""
    for candidate in g++-14 g++-13 g++; do
        if command -v "$candidate" >/dev/null 2>&1; then
            GXX_CANDIDATE="$(command -v "$candidate")"
            break
        fi
    done
    if [[ -n "$GXX_CANDIDATE" ]]; then
        ln -sf "$GXX_CANDIDATE" "$CONDA_PREFIX/bin/g++-15"
        echo "[SETUP] Created g++-15 -> $(basename "$GXX_CANDIDATE") symlink"
    else
        echo "[WARN] No usable g++ found; simpler sim builds may fail"
    fi
fi

if ! command -v gcc-15 >/dev/null 2>&1; then
    GCC_CANDIDATE=""
    for candidate in gcc-14 gcc-13 gcc; do
        if command -v "$candidate" >/dev/null 2>&1; then
            GCC_CANDIDATE="$(command -v "$candidate")"
            break
        fi
    done
    if [[ -n "$GCC_CANDIDATE" ]]; then
        ln -sf "$GCC_CANDIDATE" "$CONDA_PREFIX/bin/gcc-15"
    fi
fi

if [[ ! -x "$PTOAS_ROOT/ptoas" ]]; then
    echo "[ERROR] ptoas not found at: $PTOAS_ROOT/ptoas"
    echo "        Install a prebuilt ptoas and/or export PTOAS_ROOT before sourcing this script."
    return 1 2>/dev/null || exit 1
fi
export PTOAS_ROOT
export PATH="$PTOAS_ROOT:$PATH"

if [[ ! -d "$SIMPLER_ROOT" ]]; then
    echo "[ERROR] simpler directory not found: $SIMPLER_ROOT"
    return 1 2>/dev/null || exit 1
fi
export SIMPLER_ROOT

if ! python -c "from _task_interface import DataType" >/dev/null 2>&1; then
    echo "[WARN] _task_interface is not installed. Building simpler in the active environment..."
    (
        cd "$SIMPLER_ROOT"
        CC=/usr/bin/gcc CXX=/usr/bin/g++ pip install -e . --no-build-isolation
    )
    echo "[SETUP] simpler build/install complete"
fi

echo "==========================================="
echo " PyPTO-Lib workspace environment is active"
echo "==========================================="
echo " Conda env : $CONDA_ENV_NAME"
echo " Python    : $(command -v python)"
echo " ptoas     : $(ptoas --version 2>&1)  [$PTOAS_ROOT/ptoas]"
echo " SIMPLER   : $SIMPLER_ROOT"
echo " g++-15    : $(command -v g++-15 2>/dev/null || echo 'NOT FOUND')"
echo "==========================================="
echo
echo " Quick start:"
echo "   cd $PYPTO_LIB_ROOT"
echo "   python examples/beginner/hello_world.py -p a2a3sim -d 0"
echo "   python examples/beginner/matmul.py -p a2a3sim -d 0"
echo "   $ROOT_DIR/scripts/doctor.sh"
echo
