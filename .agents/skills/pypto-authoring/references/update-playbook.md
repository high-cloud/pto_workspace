# Update Playbook

This skill is intentionally anchored to a small set of authoring canaries.
Do not reread the whole `modules/pypto` tree for routine refreshes.

## Canary Files

These files are the minimum set to inspect when refreshing the skill:

- `modules/pypto/docs/en/user/00-getting_started.md`
- `modules/pypto/examples/hello_world.py`
- `modules/pypto/examples/kernels/03_matmul.py`
- `modules/pypto/examples/kernels/09_dyn_valid_shape.py`
- `modules/pypto/examples/models/01_ffn.py`
- `modules/pypto-lib/examples/models/qwen3/qwen3_32b_decode.py`
- `modules/pypto/python/pypto/language/parser/decorator.py`
- `modules/pypto/python/pypto/ir/compile.py`
- `modules/pypto/python/pypto/ir/pass_manager.py`
- `.agents/skills/pypto-tile-dsl/SKILL.md`

## Low-Effort Refresh Workflow

1. Run:

```bash
.agents/skills/pypto-authoring/scripts/check-canaries.sh [BASE_REF]
```

Use `origin/main` or a release tag as `BASE_REF`. If omitted, the script uses
`HEAD~20`.

2. If no canaries changed, do not update the skill.

3. If changed canaries are docs or examples only:
   update example references, small wording, or recommended patterns.

4. If changed canaries include parser, compile, or pass entrypoints:
   review whether the skill's workflow, syntax constraints, or validation
   section is now stale.

5. Keep edits small.
   Do not paste large chunks of upstream docs into the skill. Update only the
   distilled guidance.

## When a Full Refresh Is Worth It

Do a broader reread only if at least one of these happens:

- a new authoring layer appears
- `@pl.function` or `@pl.program` syntax changes
- major example taxonomy changes
- orchestration guidance changes materially
- `pypto-tile-dsl` is rewritten enough that the boundary between the two skills changes

## Maintenance Principle

This skill should describe stable authoring decisions:

- how to choose examples
- how to split kernel vs orchestration
- how to structure operator scripts vs model scripts
- how to validate cheaply

It should not try to mirror every operator or every pass detail in `modules/pypto`.
