---
name: pypto-authoring
description: >-
  Guide how to use PyPTO in this workspace to write operator scripts and model
  scripts. Use when the task is to create, extend, explain, or refactor
  `@pl.function` / `@pl.program` code under `modules/pypto` or
  `modules/pypto-lib`, including InCore kernels, orchestration, reusable
  module-level kernels, and end-to-end model examples.
---

# PyPTO Authoring

Use this skill for PyPTO authoring tasks under `modules/pypto` or
`modules/pypto-lib`.

Read first:

- `/data/yangyaodong/code/pto_workspace/AGENTS.md`
- `/data/yangyaodong/code/pto_workspace/modules/pypto/AGENTS.md`
- `/data/yangyaodong/code/pto_workspace/modules/pypto/docs/en/user/00-getting_started.md`
- `references/canonical-paths.md`

Read `references/update-playbook.md` only when refreshing this skill.
Read `references/deepseek-int8-notes.md` only when working on DeepSeek-style
INT8 quantization or similar low-precision prototype flows.

## Model

- InCore: tile-local compute, usually `load -> compute -> store`
- Orchestration: tensor allocation, scalar reads, loops, sequencing
- Large fused model blocks may use one top-level
  `@pl.function(type=pl.FunctionType.Opaque)` inside `@pl.program`

## Workflow

1. Classify the task:
   operator kernel, reusable kernel, program composition, or model block.
2. Start from the nearest canonical example.
3. Keep compute in InCore and orchestration in Orchestration.
4. Reuse existing kernels before cloning them.
5. Validate at the cheapest useful level.

## Rules

- Inside `@pl.program`, methods keep `self` first.
- Cross-method calls use `self.method(...)`.
- Module-level `@pl.function` kernels can be called directly by name.
- Use parser-supported ops only: `pl.*`, `pl.tile.*`, `pl.tensor.*`,
  `pl.system.*`.
- Use `pl.Out[...]` for output tensors written in-place.
- Keep annotations and naming close to nearby repo examples.
- `tensor DSL` is not automatically easier to lower than tile DSL. Treat
  backend shape constraints as first-class and verify early.
- In `pl.at(...)`, prefer `2D` tensor paths unless a repo example proves the
  higher-rank form is supported in the same lowering path.
- In large model scripts, put a short stage comment immediately before every
  active `with pl.at(...)`; state the tensor-level purpose of that InCore block.
- Be cautious with quantization flows that produce `[..., 1]` scale tensors:
  these often lower into fragile row/col expand patterns on A2/A3.
- When a model stage is intentionally left as TODO, keep golden aligned with
  the stages currently implemented in the program.

## Low-Precision Matmul On A2/A3

For INT8 prototype flows on A2/A3, use a conservative dataflow.

Recommended pattern:

1. Prepare stable INT8 layouts before the critical InCore path when possible.
2. Use `pl.matmul(..., out_dtype=pl.INT32)` for direct INT8 matmul.
3. Store the full INT32 result to a GM tensor first.
4. In a separate `pl.at(...)`, cast that GM-staged INT32 tensor to FP32.
5. Only then apply row extraction, relu, scaling, or reduction.

Practical rules:

- Prefer feeding the RHS in pre-transposed `[K, N]` layout.
- Do not rely on `b_trans=True` for new INT8 paths unless that exact lowering
  path is already proven in the same context.
- Avoid `pl.transpose(...)` on the RHS for new A2/A3 INT8 experiments.
- Treat program-side INT8 transpose, padding, and narrow-tile reshapes as high
  risk.
- For query-side INT8 matmul, pad rows to the backend-aligned shape first,
  typically `Q_PAD=16`.

Known fragile patterns on A2/A3:

- `pl.transpose(...)` may lower into unstable `ttrans` codegen.
- `tensor.read` or scalar extraction from temporary tiles may generate invalid
  PTO.
- `INT32` tile slicing or textract after matmul is fragile.
- Small INT8 tiles such as `1x16` or `16x1` may violate 32-byte alignment
  constraints.
- `pl.full(..., dtype=pl.INT8)` and INT8 expand/fill paths may hit backend
  restrictions.
- Program-side INT8 layout rewrites can silently corrupt data even when compile
  and runtime succeed.

## Patterns

### Operator script

- Small local math: one InCore function.
- Repeated stages: shared module-level kernels plus a `@pl.program`.
- Vector-style: default to vector ops and simple load/store flow.
- Matmul-style: follow `Mat -> Left/Right -> matmul/matmul_acc -> store`.

References:
`modules/pypto/examples/hello_world.py`
`modules/pypto/examples/kernels/01_elementwise.py`
`modules/pypto/examples/kernels/02_fused_ops.py`
`modules/pypto/examples/kernels/03_matmul.py`
`modules/pypto/examples/kernels/09_dyn_valid_shape.py`

### Model script

- Allocate intermediates with `pl.create_tensor`.
- Keep stage boundaries obvious in the main body.
- Prefer composition of reused kernels over a giant new kernel.
- For large decode or attention blocks, prefer:
  parameterized `build_*_program(...)`, derived constants near the top, stage
  comments, explicit cross-stage workspaces, and `pl.tensor.read(...)` for
  per-sample scalar state.

References:
`modules/pypto/examples/models/01_ffn.py`
`modules/pypto/examples/models/04_paged_attention.py`
`modules/pypto-lib/examples/models/qwen3/qwen3_32b_decode.py`

## Escalation

- If the task is mostly tile-memory reasoning, read
  `/data/yangyaodong/code/pto_workspace/.agents/skills/pypto-tile-dsl/SKILL.md`.
- If the task changes parser, compile, or pass behavior, inspect
  `decorator.py`, `compile.py`, and `pass_manager.py`.

## Validation

Prefer this order:

1. `print(program.as_python())`
2. focused tests
3. `ir.compile(..., dump_passes=True)`
4. device execution through `task-submit` only when needed

For low-precision authoring, keep the loop tight:

1. verify structure with `as_python()`
2. get the smallest device path running
3. check scale tensors first
4. only then chase value-level quant/dequant mismatches
5. if the smallest logits probe passes but the fused flow fails, suspect
   orchestration, GM scratch reuse, or program-side INT8 layout transforms
   before suspecting the matmul kernel

## Maintenance

- Keep this skill short and workflow-oriented.
- Do not mirror full PyPTO docs here.
- Refresh only when canary files in `references/update-playbook.md` change in a
  way that affects authoring guidance.
