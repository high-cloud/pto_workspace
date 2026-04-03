# AGENTS.md - Minimal PyPTO-Lib Workspace

This workspace is intentionally reduced to the minimum source tree needed for
`pypto-lib` development:

- `modules/pypto-lib`: examples, docs, and tests
- `modules/pypto`: compiler, bindings, runtime integration
- `modules/simpler`: CPU simulation runtime

External tools are still required, but they are not stored as submodules here:

- `ptoas`: install as a prebuilt binary and expose via `PTOAS_ROOT`
- `pto-isa`: fetched indirectly by `simpler` when needed; not managed here

## First Steps For Agents

Before changing code or running examples:

1. Read this file.
2. Run `source modules/env.sh`.
3. Run `scripts/doctor.sh`.
4. Read module-specific instructions when working inside:
   - `modules/pypto/AGENTS.md`
   - `modules/simpler/AGENTS.md`

If `scripts/doctor.sh` fails, fix the environment before debugging examples.

## Canonical Environment Flow

The supported development path is CPU simulation on `a2a3sim`.

```bash
source modules/env.sh
scripts/doctor.sh
cd modules/pypto-lib
python examples/beginner/hello_world.py -p a2a3sim -d 0
```

## Required Environment

- Python 3.10 in conda env `pypto-lib`
- `modules/pypto` installed into that environment
- `modules/simpler` installed into that environment
- `PTOAS_ROOT` pointing to a working prebuilt `ptoas`
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
source modules/env.sh
scripts/doctor.sh

cd modules/pypto
PYTHONPATH=$(pwd)/python:$PYTHONPATH python -m pytest tests/ut/core/test_error.py -v

cd /path/to/pto_workspace/modules/pypto-lib
python examples/beginner/hello_world.py -p a2a3sim -d 0
python examples/beginner/matmul.py -p a2a3sim -d 0
```
