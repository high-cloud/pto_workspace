---
name: pypto-orchestration-perf
description: >-
  Analyze and optimize PyPTO orchestration/runtime parallelism from profiling
  output. Use when the task mentions swimlane JSON, runtime profiling,
  scheduler overhead, task count, unique_tids, generated orchestration C++,
  whole-tensor inout serialization, tensor view writeback, or optimizing
  PyPTO model/example kernels without changing math.
---

# PyPTO Orchestration Performance

Use this skill for PyPTO performance work where the bottleneck may be task
scheduling, lost parallelism, orchestration dependencies, or generated runtime
shape. This is separate from tile DSL correctness and low-level tile-kernel
authoring.

## Read First

- Root policy: `AGENTS.md`
- Detailed note:
  `modules/pypto-lib/docs/orchestration_parallelism_patterns.md`
- Loop semantics:
  `modules/pypto-lib/docs/para_for.md`
- Runtime profiling context:
  `modules/pypto-lib/docs/pto2_rt.md`

## When This Applies

- User asks why one PyPTO script is slower than another.
- User provides `build_output/*/swimlane_data/merged_swimlane*.json`.
- Profiling shows many tasks but low lane occupancy.
- Generated orchestration has repeated `params.add_inout(...)` inside loops.
- A loop writes independent tensor blocks, but runtime schedules it serially.
- User asks for optimization patterns for other kernels.

## Core Rule

For independent loop iterations, make the generated task operate on a sliced
view of the output tensor, not the whole tensor.

Preferred generated shape:

```cpp
Tensor out_view = out.view(...);
params.add_inout(out_view);
```

Risky generated shape inside a loop:

```cpp
params.add_inout(out);
```

Whole-tensor `inout` can make the scheduler treat disjoint writes as dependent
updates to the same tensor object.

## Source Pattern

Prefer an outer loop where each iteration owns one non-overlapping output
region, computes into a local temporary, then writes that region back.

```python
for outer in pl.parallel(0, extent, outer_tile):
    with pl.at(level=pl.Level.CORE_GROUP):
        local = pl.create_tensor([rows, outer_tile], dtype=dtype)
        for inner in pl.parallel(0, outer_tile, inner_tile):
            block = compute_block(outer + inner)
            local = pl.assemble(local, block, [0, inner])
    dst = pl.assemble(dst, local, [base_row, outer])
```

Be suspicious of direct whole-output assembly in a fine-grained parallel loop:

```python
for i in pl.parallel(num_blocks, chunk=chunk):
    block = compute_block(i)
    dst = pl.assemble(dst, block, [offset(i), 0])
```

This can lower poorly if the compiler cannot expose a sliced tensor view for
the task argument.

## Analysis Workflow

1. Identify the build outputs being compared.
   Look under `build_output/*/swimlane_data/merged_swimlane*.json`,
   `orchestration/*.cpp`, and `kernel_config.py`.

2. Summarize task counts, wall time, and lane usage from swimlane JSON.

```bash
jq -r '
  [.traceEvents[]
   | select(.pid==1 and .ph=="X" and (.name|test("^func_")))
   | {func:(.name|capture("^(?<f>func_[0-9]+_[a-z])").f), tid, dur}]
  | group_by(.func)
  | map({func:.[0].func,
         count:length,
         unique_tids:(map(.tid)|unique|length),
         avg_dur:(map(.dur)|add/length)})
  | sort_by(.func)
  | .[]
' build_output/.../swimlane_data/merged_swimlane*.json
```

3. Treat `count` high plus `unique_tids` near 1 as a serialization signal.

4. Open generated `orchestration/*.cpp` for the hot `func_id`.
   Check whether loop-submitted tasks use whole tensors or `tensor.view(...)`.

5. Map the generated task back to Python source by matching loop structure,
   scalar arguments, tensor names, and nearby `Task N: ...` comments.

6. Refactor source to expose disjoint output regions, then reprofile.
   Validate correctness with golden output when available.

## What To Report

When explaining a performance difference, include:

- Which function IDs have high count and low `unique_tids`.
- Whether generated orchestration uses `add_inout(whole_tensor)` or sliced views.
- The source loop responsible for that generated shape.
- A concrete source-level rewrite, scoped to orchestration/writeback structure.
- Any memory-pressure risk from larger local temporaries.

## Caveats

- Do not force parallelism for loops with real loop-carried dependencies.
- Larger local tensors can improve scheduling but increase memory pressure.
  Check `report/memory_after_AllocateMemoryAddr.txt`.
- More tasks is not automatically worse; many small tasks with poor occupancy
  are the real warning sign.
- `pl.pipeline` can help long scans or K-dimension accumulation, but it does not
  by itself fix whole-tensor dependency edges.
