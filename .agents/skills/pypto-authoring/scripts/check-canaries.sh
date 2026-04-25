#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

BASE_REF="${1:-HEAD~20}"

CANARIES=(
  "modules/pypto/docs/en/user/00-getting_started.md"
  "modules/pypto/examples/hello_world.py"
  "modules/pypto/examples/kernels/03_matmul.py"
  "modules/pypto/examples/kernels/09_dyn_valid_shape.py"
  "modules/pypto/examples/models/01_ffn.py"
  "modules/pypto-lib/examples/models/qwen3/qwen3_32b_decode.py"
  "modules/pypto/python/pypto/language/parser/decorator.py"
  "modules/pypto/python/pypto/ir/compile.py"
  "modules/pypto/python/pypto/ir/pass_manager.py"
  ".agents/skills/pypto-tile-dsl/SKILL.md"
)

echo "BASE_REF=$BASE_REF"
echo
echo "Changed canaries since $BASE_REF:"

changed=0
for path in "${CANARIES[@]}"; do
  if ! git diff --quiet "$BASE_REF" -- "$path"; then
    changed=1
    echo "  CHANGED  $path"
  fi
done

if [[ "$changed" -eq 0 ]]; then
  echo "  none"
  exit 0
fi

echo
echo "Suggested next commands:"
echo "  git diff --stat \"$BASE_REF\" -- ${CANARIES[*]}"
echo "  git diff \"$BASE_REF\" -- modules/pypto/docs/en/user/00-getting_started.md"
echo "  git diff \"$BASE_REF\" -- modules/pypto/examples/models/01_ffn.py"
