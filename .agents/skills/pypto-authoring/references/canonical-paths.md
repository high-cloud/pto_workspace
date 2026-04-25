# Canonical Paths

Use these files as the primary anchor points for PyPTO authoring guidance.
Read only the ones relevant to the current task.

## User-Level Entry Points

- Quick start:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/docs/en/user/00-getting_started.md`
- Language guide:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/docs/en/user/01-language_guide.md`
- Package entry:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/python/pypto/__init__.py`

## Example Ladder

- Minimal program:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/examples/hello_world.py`
- Vector kernels:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/examples/kernels/01_elementwise.py`
  `/data/yangyaodong/code/pto_workspace/modules/pypto/examples/kernels/02_fused_ops.py`
- Cube matmul:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/examples/kernels/03_matmul.py`
- Dynamic valid-shape:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/examples/kernels/09_dyn_valid_shape.py`
- Model composition:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/examples/models/01_ffn.py`
  `/data/yangyaodong/code/pto_workspace/modules/pypto/examples/models/04_paged_attention.py`
- Large staged decode:
  `/data/yangyaodong/code/pto_workspace/modules/pypto-lib/examples/models/qwen3/qwen3_32b_decode.py`

## Compiler Entry Points

- DSL parser decorator:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/python/pypto/language/parser/decorator.py`
- Compile API:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/python/pypto/ir/compile.py`
- Pass strategy:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/python/pypto/ir/pass_manager.py`

## Deep References

- Tile DSL specifics:
  `/data/yangyaodong/code/pto_workspace/.agents/skills/pypto-tile-dsl/SKILL.md`
- IR overview:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/docs/en/dev/ir/00-overview.md`
- Pass manager overview:
  `/data/yangyaodong/code/pto_workspace/modules/pypto/docs/en/dev/passes/00-pass_manager.md`

## Recommended Reading Order

1. `00-getting_started.md`
2. the nearest example
3. `decorator.py` only if syntax or parser behavior matters
4. `compile.py` and `pass_manager.py` only if compilation behavior matters
