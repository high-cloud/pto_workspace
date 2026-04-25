---
name: pypto-tile-dsl
description: >-
  Read, write, and review PyPTO tile DSL code in this workspace. Use when the
  task involves `@pl.function` / `@pl.program`, InCore kernels, tile operators,
  load-store pipelines, memory-space moves, dynamic valid-shape handling, or
  orchestration that composes tile kernels into examples or model flows.
---

# PyPTO Tile DSL

Use this skill when working on PyPTO DSL code under `modules/pypto` or
`modules/pypto-lib` that is built around tile kernels.

## Read First

- Root policy: `/home/yyd/code/my_projects/pto_workspace/AGENTS.md`
- PyPTO module policy: `/home/yyd/code/my_projects/pto_workspace/modules/pypto/AGENTS.md`
- PyPTO project rules entrypoint: `/home/yyd/code/my_projects/pto_workspace/modules/pypto/.claude/CLAUDE.md`

## What Counts As Tile DSL

Typical pattern inside an InCore kernel:

```python
@pl.function(type=pl.FunctionType.InCore)
def kernel(
    x: pl.Tensor[[M, N], pl.FP32],
    out: pl.Out[pl.Tensor[[M, N], pl.FP32]],
) -> pl.Tensor[[M, N], pl.FP32]:
    tile_x = pl.load(x, [0, 0], [M, N], target_memory=pl.MemorySpace.Vec)
    tile_y = pl.relu(tile_x)
    return pl.store(tile_y, [0, 0], out)
```

Core signals:

- `@pl.function(type=pl.FunctionType.InCore)`
- `pl.load(...)` and `pl.store(...)`
- tile values annotated as `pl.Tile[...]`
- tile ops through `pl.*` or `pl.tile.*`
- explicit memory spaces such as `Vec`, `Mat`, `Left`, `Right`, `Acc`

`@pl.function(type=pl.FunctionType.Orchestration)` is the layer above tile
kernels: it allocates tensors, slices views, reads scalar config, loops, and
calls InCore functions.

## Canonical Examples

Read only the files relevant to the task.

- Smallest kernel: `modules/pypto/examples/hello_world.py`
- Elementwise and fused vector kernels:
  `modules/pypto/examples/kernels/01_elementwise.py`,
  `modules/pypto/examples/kernels/02_fused_ops.py`
- Cube matmul and accumulation: `modules/pypto/examples/kernels/03_matmul.py`
- Activation / softmax / norm kernels:
  `modules/pypto/examples/kernels/05_activation.py`,
  `modules/pypto/examples/kernels/06_softmax.py`,
  `modules/pypto/examples/kernels/07_normalization.py`
- Dynamic valid-shape patterns:
  `modules/pypto/examples/kernels/09_dyn_valid_shape.py`
- Kernel composition and orchestration:
  `modules/pypto/examples/models/01_ffn.py`,
  `modules/pypto/examples/models/04_paged_attention.py`,
  `modules/pypto/examples/models/05_paged_attention_batch.py`

## Writing Rules

1. Separate kernel code from orchestration code.
   Use InCore functions for tile-local compute and Orchestration functions for
   loops, `create_tensor`, `slice`, config reads, and kernel sequencing.

2. Prefer the established load-op-store shape.
   Vector kernel:
   `load -> vector ops -> optional scratch tile -> store`
   Cube kernel:
   `load(Mat) -> move(Left/Right) -> matmul/matmul_acc -> store`

3. Be explicit about memory space when the op depends on it.
   Matmul-family code should state `Mat`, `Left`, and `Right`.
   Scratch reductions usually use
   `pl.create_tile(..., target_memory=pl.MemorySpace.Vec)`.

4. Keep shapes static in type annotations unless the pattern already uses
   dynamic dimensions. If runtime values affect valid extents, use
   `valid_shapes=[...]` and then `pl.tile.fillpad(...)`.

5. Reuse module-level kernels when multiple programs share them.
   See `modules/pypto/examples/models/01_ffn.py` and
   `modules/pypto/examples/models/04_paged_attention.py`.

6. For cross-function calls inside `@pl.program`, use `self.method(...)`.
   Module-level external `@pl.function` calls are also supported by name.

## DSL Constraints That Matter

- `@pl.program` methods must declare `self` first; the parser strips it from IR.
- Inside `@pl.program`, `self.method(...)` only works for methods decorated with
  `@pl.function`.
- Use `pl.*`, `pl.tile.*`, `pl.tensor.*`, or `pl.system.*` operations. Do not
  invent helper call syntax the parser does not know.
- If the user wants explicit dispatch, prefer `pl.tile.*` and `pl.tensor.*`.
  `pl.add`, `pl.exp`, `pl.row_sum`, and similar names are unified ops that
  dispatch by input type.

Relevant implementation references:

- `modules/pypto/python/pypto/language/op/__init__.py`
- `modules/pypto/python/pypto/language/typing/tile.py`
- `modules/pypto/python/pypto/language/parser/decorator.py`
- `modules/pypto/python/pypto/language/parser/ast_parser.py`

## Common Patterns

### Elementwise vector kernel

- `tile_x = pl.load(...)`
- `tile_y = pl.mul(tile_x, scalar)` or `pl.add(tile_x, tile_z)`
- `out = pl.store(tile_y, ..., output)`

### Row reduction and broadcast

- Create scratch tile in `Vec`
- `row_stat = pl.row_max(...)` or `pl.row_sum(...)`
- `broadcasted = pl.row_expand_*(...)`

### Cube matmul

- `a_l1 = pl.load(..., target_memory=pl.MemorySpace.Mat)`
- `b_l1 = pl.load(..., target_memory=pl.MemorySpace.Mat, transpose=...)`
- `a_l0 = pl.move(a_l1, target_memory=pl.MemorySpace.Left)`
- `b_l0 = pl.move(b_l1, target_memory=pl.MemorySpace.Right)`
- `acc = pl.matmul(...)` or `pl.matmul_acc(...)`

### Dynamic valid-shape

- Compute `vlen` from branch or loop state
- `tile = pl.load(..., valid_shapes=[rows, vlen])`
- `padded = pl.tile.fillpad(tile, pad_value=...)`

## Review Checklist

- Does each InCore function have a clear tile-level dataflow?
- Are memory spaces correct for the target ops?
- Are scratch tiles allocated in the right shape and space?
- Are dynamic extents handled with `valid_shapes` and padding rather than ad hoc slicing alone?
- Is orchestration logic kept out of the kernel unless required by the DSL pattern?
- If a shared kernel already exists, should this code reuse it?

## Validation

When code changes are made:

- Prefer a focused unit test or example run over broad validation first.
- For parser or DSL changes in `modules/pypto`, use the PyPTO testing workflow
  from `modules/pypto/.claude/skills/testing/SKILL.md`.
- For example-only changes, at minimum print or parse the program and verify the
  generated Python or IR shape looks right.
