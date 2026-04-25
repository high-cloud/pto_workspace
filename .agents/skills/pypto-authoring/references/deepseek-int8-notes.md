# DeepSeek INT8 Notes

Use this note when prototyping DeepSeek-style INT8 quantization flows in
`modules/pypto` or `modules/pypto-lib`.

## Scope

This is not a general PyPTO guide. It captures practical lessons from trying to
express a DeepSeek V3.2-style INT8 quant/dequant chain in the current A2/A3
toolchain.

## Main lessons

- Distinguish frontend authoring problems from backend lowering problems.
  Many failures in these experiments came from shape/layout lowering rather than
  from the quantization formula itself.
- `x_scale` passing while `x_q` and `x_back` fail is an important signal.
  It usually means the `amax/scale` math is correct and the remaining bug is in
  cast, broadcast, layout, or dequant consumption.
- Treat `[..., 1]` scale tensors as risky on A2/A3.
  They often lower into FP32 Vec tiles such as `[N, 1]`, which can trigger
  alignment or legality failures.
- In `pl.at(...)`, avoid `>2D` tensor slices unless a known-good example uses
  the same pattern. The current lowering path may reject them during
  flatten-to-2D passes.
- A tensor DSL rewrite does not automatically eliminate backend issues.
  It can improve readability, but the same shape may still lower into the same
  illegal tile form.
- Derive host-side debug or prebuilt quantized inputs from the same source dtype
  the program consumes, e.g. BF16 -> quant rather than FP32 -> quant, or small
  `+-1` mismatches can hide the real backend issue.
- For unfinished fused decode scripts, validate the last implemented
  pre-topk tensor, such as `scores_out`, before enabling the topk path.
- Do not add future-stage math to golden while the program still keeps that
  stage as a TODO. First align golden with implemented stages, then debug real
  program mismatches.

## Quant chain

When matching deployment-side INT8 reference logic, prefer to model the cast
chain explicitly instead of collapsing everything into a direct cast:

1. `FP32`
2. `INT32` with `round`
3. `FP16` with `round`
4. `INT8` with `trunc`

This is closer to the observed DeepSeek-side reference flow than a direct
`FP32 -> INT8` cast.

## Practical debugging order

1. Confirm `program.as_python()` prints the structure you intended.
2. Run the smallest possible device job through `task-submit`.
3. Check whether scale outputs match golden before investigating value outputs.
4. If values are close but off by 1 step, suspect cast-chain semantics before
   suspecting the core quant formula.
5. If many score mismatches are `0` versus `PadValue.min` or `-inf`, inspect
   valid-shape, masking, and unwritten padded regions before debugging matmul
   precision.
6. If compile/lowering fails, inspect the generated `.pto` or pass report to
   determine whether the issue is:
   - shape legality
   - buffer pressure
   - specific op lowering such as transpose/broadcast/cast

## A2/A3 INT8 matmul path that was validated

The following path is known-good in this workspace for a minimal logits probe:

1. `q_int8_padded` provided as `[Q_PAD, D]`, typically `Q_PAD=16`
2. `k_int8_t` provided as pre-transposed `[D, S]`
3. `pl.matmul(q_int8_padded, k_int8_t, out_dtype=pl.INT32)`
4. Store the full INT32 logits to GM
5. In a separate `pl.at(...)`, cast that GM-staged INT32 tensor to FP32

This passed device validation for a standalone logits probe. The core direct
`INT8 -> INT32` matmul path itself appears sound when fed stable layouts.

References:

- `modules/pypto-lib/examples/models/deepseek_v3_2/deepseek_v3_2_int8_matmul_probe.py`
- `modules/pypto-lib/examples/models/deepseek_v3_2/deepseek_v3_2_int8_matmul_via_f32_probe.py`
- `modules/pypto-lib/examples/models/deepseek_v3_2/deepseek_v3_2_int8_index_score_logits_probe.py`

## Known failure patterns seen in this workspace

- FP32 `[N, 1]` Vec tiles can fail backend alignment checks.
- `>2D` tensor slicing inside `pl.at(...)` can fail flatten-to-2D passes.
- Large tensor DSL blocks may exceed Vec buffer limits even when the math is
  simple.
- Some legal-looking tensor DSL programs can still fail in `ptoas` due to the
  generated PTO syntax for a specific op combination.
- `pl.transpose(...)` on A2/A3 INT8 paths can lower into unstable `ttrans`
  codegen.
- `b_trans=True` is not a safe default for new INT8 score paths.
- `tensor.read` / `tgetval` / scalar extraction from temporary tiles can
  generate invalid PTO.
- `INT32` tile slicing or textract after matmul is fragile.
- Program-side INT8 transpose, padding, or row-to-column reshaping can silently
  corrupt data even when compile and runtime succeed.
- Small INT8 tiles such as `1x16` or `16x1` can violate 32-byte alignment
  constraints.

## Recommended DeepSeek INT8 score dataflow

For DeepSeek-style index-score prototypes on A2/A3:

- Quantize `q` and `k` row-wise in-program if you need to validate the quant
  chain.
- Keep quant outputs as visible tensors for golden comparison.
- For the score matmul itself, use a proven layout path. If program-side layout
  prep is not yet validated, prefer host-prepared `q_int8_padded` and
  `k_int8_t`.
- In fused decode paths, a validated scores-out staging sequence is:
  - pad q-side INT8 rows to `Q_PAD=16`
  - compute INT8 qk logits with `out_dtype=pl.INT32`
  - store the full INT32 logits to GM
  - cast GM-staged INT32 logits to FP32 in a separate `pl.at(...)`
  - extract the valid q row, apply ReLU, reduce across heads with `q_s`, then
    apply `k_scale`
- Avoid rebuilding INT8 transpose/padding layouts inside the program unless
  there is a proven lowering path for the exact reshape/store pattern.
- When validating an incomplete topk pipeline, expose and compare `scores_out`
  before enabling sort/gather/mask stages.

Interpretation rule:

- If quant outputs and scales pass but logits fail, suspect layout prep or
  orchestration before suspecting the quant formula.
- If a standalone logits probe passes but the fused flow fails, suspect
  temporary tensor reuse or program-side INT8 layout rewrites before suspecting
  the direct INT8 matmul kernel.
- If `scores_out` differs only in padded tail positions, align golden masking
  or valid-shape semantics before changing kernels.

## Authoring advice

- Prefer small, staged prototypes over jumping directly into the full model.
- Keep the first runnable version as close as possible to the device reference
  math, but allow intermediate representation changes if the backend requires
  them.
- In large fused decode examples, add a short stage comment immediately before
  every active `with pl.at(...)`. This makes later partial-stage debugging and
  golden alignment much less ambiguous.
- For large device-orchestration decode examples, a larger `PTO2_RING_HEAP` may
  be required before runtime validation. Treat hangs or scheduler stalls
  separately from numerical mismatches.
- When a tensor DSL version and a tile DSL version disagree, use the version
  that already runs on device as the temporary reference point for narrowing the
  next mismatch.
