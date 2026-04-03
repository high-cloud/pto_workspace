# PyPTO-Lib 环境搭建指南

## 概述

本指南记录搭建可运行 pypto-lib examples 环境的完整过程。当前工作区只保留 `pypto-lib`、`pypto`、`simpler` 三个源码模块；`ptoas` 作为外部预编译工具安装。**经实际验证，编译 + 执行 + 结果验证均可在无 Ascend NPU 硬件的 x86 机器上完成**，通过 simpler 的 `a2a3sim` CPU 模拟模式。

## 环境信息

- **操作系统**: Linux x86_64 (Ubuntu)
- **Python 版本**: 3.10
- **Conda 环境**: `pypto-lib`
- **ptoas 版本**: v0.19 (预编译二进制)
- **simpler 版本**: v0.1.0 (从源码编译)
- **g++**: 需要 g++-15 (或创建 g++-13 的符号链接)

## 步骤 1: 创建 Conda 环境

```bash
conda create -n pypto-lib python=3.10 -y
conda activate pypto-lib
```

## 步骤 2: 安装基础依赖

```bash
pip install torch numpy cmake ninja
pip install scikit-build-core nanobind
pip install pybind11
```

## 步骤 3: 安装 PyPTO（核心框架）

```bash
cd /path/to/pto_workspace/modules/pypto
pip install -e . --no-build-isolation
```

验证：
```bash
python -c "import pypto; print('pypto OK')"
```

## 步骤 4: 下载并安装 PTOAS 预编译二进制

```bash
mkdir -p ~/.local/ptoas/v0.19
curl -L -o /tmp/ptoas-bin.tar.gz \
    "https://github.com/zhangstevenunity/PTOAS/releases/download/v0.19/ptoas-bin-x86_64.tar.gz"
tar -xzf /tmp/ptoas-bin.tar.gz -C ~/.local/ptoas/v0.19
chmod +x ~/.local/ptoas/v0.19/ptoas ~/.local/ptoas/v0.19/bin/*
```

验证：
```bash
~/.local/ptoas/v0.19/ptoas --version
```

## 步骤 5: 编译安装 Simpler（CPU 模拟运行时）

simpler 提供 `code_runner` 模块和 `a2a3sim` 平台，可在 CPU 上通过线程模拟执行 PTO 编译产物。

```bash
# 5a. 确保 g++-15 可用（simpler 的 sim toolchain 硬编码了 g++-15）
# 如果系统没有 g++-15，创建符号链接：
ln -sf /usr/bin/g++-13 $CONDA_PREFIX/bin/g++-15
ln -sf /usr/bin/gcc-13 $CONDA_PREFIX/bin/gcc-15

# 5b. 编译安装 simpler（会编译 _task_interface C++ nanobind 模块）
cd /path/to/pto_workspace/modules/simpler
export CC=/usr/bin/gcc
export CXX=/usr/bin/g++
pip install -e . --no-build-isolation
```

验证：
```bash
python -c "from _task_interface import DataType; print('_task_interface OK')"
```

## 步骤 6: 设置环境变量并运行示例

```bash
# 每次激活环境后需要执行
export PTOAS_ROOT=~/.local/ptoas/v0.19
export PATH=$PTOAS_ROOT:$PATH
export SIMPLER_ROOT=/path/to/pto_workspace/modules/simpler

cd /path/to/pto_workspace/modules/pypto-lib

# 运行 hello_world（编译 + CPU 模拟执行 + 结果验证）
python examples/beginner/hello_world.py -p a2a3sim -d 0

# 运行 matmul
python examples/beginner/matmul.py -p a2a3sim -d 0
```

**预期输出**：
```
[INFO] === All 1 cases passed ===
```

完整流程：`pypto IR 编译 → ptoas 生成 C++ kernel → g++ 编译为 .so → simpler 线程模拟执行 → 结果对比验证`

## 一键激活与自检

优先使用仓库自带脚本：

```bash
source scripts/env.sh
scripts/doctor.sh
```

## 可用示例列表

| 路径 | 说明 |
|------|------|
| `examples/beginner/hello_world.py` | elementwise add_one ✅ 已验证 |
| `examples/beginner/matmul.py` | 分块矩阵乘法 ✅ 已验证 |
| `examples/intermediate/rms_norm.py` | RMS 归一化 |
| `examples/intermediate/softmax.py` | Softmax |
| `examples/intermediate/rope.py` | Rotary Position Embedding |
| `examples/intermediate/gemm.py` | 通用矩阵乘法 |
| `examples/intermediate/layer_norm.py` | Layer Normalization |
| `examples/qwen3/qwen3_32b_decode_tilelet.py` | Qwen3 32B 解码 tilelet |

## 依赖关系图

```
pypto-lib examples
    ├── pypto (Python 编程框架，从源码编译)
    │   ├── numpy >= 2.0
    │   ├── torch >= 2.0
    │   └── scikit-build-core + nanobind (编译工具)
    ├── PTOAS (编译器，预编译二进制)
    │   └── LLVM/MLIR 19.1.7 (已打包)
    └── simpler (运行时 pto-rt2，从源码编译)
        ├── _task_interface (C++ nanobind 模块)
        ├── code_runner.py (编排编译+执行)
        ├── kernel_compiler.py (kernel → .so)
        ├── runtime_compiler.py (host runtime → .bin)
        └── pto-isa (由 simpler 在需要时自行拉取/缓存)
```

## CPU 模拟执行原理

simpler 的 `a2a3sim` 平台通过以下方式在 CPU 上模拟 NPU 执行：

1. **线程模拟**: 每个 AICore/AICPU 作为独立 host 线程运行
2. **内存模拟**: `malloc`/`free` 模拟设备内存 (GM/L1/L2)
3. **寄存器模拟**: 每核心分配模拟寄存器块
4. **编译替换**: 用 `g++ -D__CPU_SIM` 替代 `ccec` 编译 kernel
5. **相同 API**: 与真实硬件使用完全相同的接口

## 常见问题

### Q1: `pip install -e .` 报错 "Cannot import 'scikit_build_core.build'"

```bash
pip install scikit-build-core nanobind
```

### Q2: 运行示例报错 "ptoas binary not found"

```bash
export PTOAS_ROOT=~/.local/ptoas/v0.19
export PATH=$PTOAS_ROOT:$PATH
```

### Q3: `ModuleNotFoundError: No module named 'code_runner'`

需要设置 `SIMPLER_ROOT` 环境变量，pypto 通过它找到 simpler 的 `code_runner.py`：
```bash
export SIMPLER_ROOT=/path/to/pto_workspace/modules/simpler
```

### Q4: `PermissionError: [Errno 13] Permission denied: 'g++-15'`

simpler 的 simulation toolchain 硬编码了 `g++-15`。如果系统没有 g++-15：
```bash
# 在 conda 环境中创建符号链接
ln -sf /usr/bin/g++-13 $CONDA_PREFIX/bin/g++-15
ln -sf /usr/bin/gcc-13 $CONDA_PREFIX/bin/gcc-15
```

### Q5: `ModuleNotFoundError: No module named '_task_interface'`

simpler 没有正确编译安装。需要从源码构建：
```bash
cd /path/to/pto_workspace/modules/simpler
export CC=/usr/bin/gcc && export CXX=/usr/bin/g++
pip install -e . --no-build-isolation
```

### Q6: ptoas 下载 403 错误

GitHub API 限流。手动在浏览器下载：
1. 访问 https://github.com/zhangstevenunity/PTOAS/releases
2. 下载最新版本的 `ptoas-bin-x86_64.tar.gz`
3. 手动解压到 `~/.local/ptoas/<version>/`

## 参考资料

- pypto: https://github.com/hw-native-sys/pypto
- PTOAS: https://github.com/zhangstevenunity/PTOAS
- PTOAS Releases: https://github.com/zhangstevenunity/PTOAS/releases
- simpler: https://github.com/ChaoWao/simpler
- pypto-lib README: `modules/pypto-lib/README.md`

---

*最后更新: 2026-04-01*
