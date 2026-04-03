# Development Environment

This repository is optimized for `pypto-lib` development with local sources for:

- `modules/pypto`
- `modules/pypto-lib`
- `modules/simpler`

The assembler is expected as an external install:

- `ptoas` at `~/.local/ptoas/v0.19` by default

## Recommended Setup

1. Create and activate the conda environment.

```bash
conda create -n pypto-lib python=3.10 -y
conda activate pypto-lib
```

2. Install Python build dependencies.

```bash
pip install torch numpy cmake ninja scikit-build-core nanobind pybind11
```

3. Install local source modules.

```bash
cd modules/pypto
pip install -e . --no-build-isolation

cd ../simpler
CC=/usr/bin/gcc CXX=/usr/bin/g++ pip install -e . --no-build-isolation
```

4. Install prebuilt `ptoas`.

```bash
mkdir -p ~/.local/ptoas/v0.19
tar -xzf ptoas-bin-x86_64.tar.gz -C ~/.local/ptoas/v0.19
chmod +x ~/.local/ptoas/v0.19/ptoas ~/.local/ptoas/v0.19/bin/*
```

5. Activate the workspace environment.

```bash
source modules/env.sh
scripts/doctor.sh
```

## What `scripts/doctor.sh` Checks

- conda environment activation state
- `python` path
- `pypto` import
- `_task_interface` import
- `PTOAS_ROOT` and `ptoas --version`
- `SIMPLER_ROOT`
- one smoke import path into `pypto-lib`

## Common Recovery Steps

- If `pypto` cannot import: reinstall `modules/pypto`
- If `_task_interface` cannot import: reinstall `modules/simpler`
- If `ptoas` is missing: reinstall the prebuilt binary and export `PTOAS_ROOT`
- If `g++-15` is missing: let `modules/env.sh` create a symlink inside the conda env
