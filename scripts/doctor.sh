#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_ENV="${CONDA_DEFAULT_ENV:-}"
STATUS=0

check_cmd() {
    local name="$1"
    shift
    if "$@"; then
        echo "[OK] ${name}"
    else
        echo "[FAIL] ${name}"
        STATUS=1
    fi
}

echo "== Workspace Doctor =="
echo "root      : ${ROOT_DIR}"
echo "python    : $(command -v python || echo 'NOT FOUND')"
echo "conda env : ${EXPECTED_ENV:-NOT ACTIVE}"
echo

check_cmd "python available" command -v python
check_cmd "conda env active" test -n "${EXPECTED_ENV}"
check_cmd "pypto import" python -c "import pypto"
check_cmd "_task_interface import" python -c "from _task_interface import DataType"
check_cmd "SIMPLER_ROOT set" test -n "${SIMPLER_ROOT:-}"
check_cmd "SIMPLER_ROOT exists" test -d "${SIMPLER_ROOT:-/nonexistent}"
check_cmd "PTOAS_ROOT set" test -n "${PTOAS_ROOT:-}"
check_cmd "ptoas executable" test -x "${PTOAS_ROOT:-/nonexistent}/ptoas"
check_cmd "ptoas version" "${PTOAS_ROOT:-/nonexistent}/ptoas" --version >/dev/null 2>&1
check_cmd "pypto-lib example import path" bash -lc "cd '${ROOT_DIR}/modules/pypto-lib' && python -c 'import pypto.language as pl'"

echo
if [[ "${STATUS}" -eq 0 ]]; then
    echo "Doctor result: PASS"
else
    echo "Doctor result: FAIL"
fi

exit "${STATUS}"
