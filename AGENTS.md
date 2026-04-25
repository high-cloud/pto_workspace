# AGENTS.md - Minimal PyPTO-Lib Workspace

This workspace is intentionally reduced to the minimum source tree needed for
`pypto-lib` development:

- `modules/pypto-lib`: examples, docs, and tests
- `modules/pypto`: compiler, bindings, runtime integration
- `modules/simpler`: optional CPU simulation runtime; it may be absent in this
  reduced workspace

External tools are still required, but they are not stored as submodules here:

- `ptoas`: install as a prebuilt binary and expose via `PTOAS_ROOT`
- `pto-isa`: available under `modules/pto-isa` or fetched indirectly by
  `simpler` when CPU simulation is used

## First Steps For Agents

Before changing code or running examples:

1. Read this file.
2. Run `source scripts/env.sh`.
3. Run `scripts/doctor.sh`.
4. Read module-specific instructions when working inside:
   - `modules/pypto/AGENTS.md`
   - `modules/simpler/AGENTS.md` if `modules/simpler` exists

If `scripts/doctor.sh` reports required-check failures, fix the environment
before debugging examples. Warnings about missing `modules/simpler` only affect
CPU simulation; NPU jobs should use `task-submit`.

## Canonical Environment Flow

The supported NPU execution path uses the shared task queue.

```bash
source scripts/env.sh
scripts/doctor.sh
cd modules/pypto-lib
task-submit --device auto --run "python examples/beginner/hello_world.py -p a2a3 -d {}"
```

## Required Environment

- Python 3.10 in conda env `pypto-lib`
- `modules/pypto` installed into that environment
- `PTOAS_ROOT` pointing to a working prebuilt `ptoas`
- `task-submit` for NPU/Ascend device runs

Optional for CPU simulation:

- `modules/simpler` installed into that environment
- `SIMPLER_ROOT` pointing to `modules/simpler`

Detailed setup instructions live in:

- `docs/dev_environment.md`
- `modules/PYPTO_LIB_SETUP_GUIDE.md`

## Workspace Policy

- Treat this repository as a `pypto-lib` workspace, not a monorepo for all PTO projects.
- Do not reintroduce unrelated submodules unless explicitly requested.
- Prefer CPU-sim validation first.
- Keep environment instructions and diagnostics in-repo so future agents can recover context after a fresh clone.

## Useful Commands

```bash
source scripts/env.sh
scripts/doctor.sh

cd modules/pypto
PYTHONPATH=$(pwd)/python:$PYTHONPATH python -m pytest tests/ut/core/test_error.py -v

cd /path/to/pto_workspace/modules/pypto-lib
task-submit --device auto --run "python examples/beginner/hello_world.py -p a2a3 -d {}"
python examples/beginner/hello_world.py -p a2a3sim -d 0  # if modules/simpler exists
python examples/beginner/matmul.py -p a2a3sim -d 0       # if modules/simpler exists
```

## Local Skills

Repository-specific skills live under `.agents/skills/`.

- `pypto-tile-dsl`: guidance for reading, writing, and reviewing PyPTO tile DSL
  kernels and orchestration in this workspace
- `task-submit`: submit NPU/Ascend work through the shared task queue instead
  of running device jobs directly

When a task matches one of these skills, read its `SKILL.md` before editing
code.
