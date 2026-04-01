#!/bin/bash
# ---------------------------------------------------------------------------
# PyPTO-Lib 一键环境启动脚本
# 用法: source env.sh
# ---------------------------------------------------------------------------
set -euo pipefail

# ---------- 配置区（按实际路径修改）----------
WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONDA_ENV_NAME="pypto-lib"
PTOAS_ROOT="$HOME/.local/ptoas/v0.19"
SIMPLER_ROOT="$WORKSPACE/simpler"
PYPTO_LIB_ROOT="$WORKSPACE/pypto-lib"

# ---------- Conda 环境 ----------
# shellcheck disable=SC1091
source "$(conda info --base)/etc/profile.d/conda.sh"

if ! conda activate "$CONDA_ENV_NAME" 2>/dev/null; then
    echo "[ERROR] conda 环境 '$CONDA_ENV_NAME' 不存在，请先运行以下命令创建："
    echo "  conda create -n $CONDA_ENV_NAME python=3.10 -y"
    return 1 2>/dev/null || exit 1
fi

# ---------- g++-15 兼容 ----------
# simpler 的 sim toolchain 硬编码了 g++-15，若系统没有则创建符号链接
if ! command -v g++-15 &>/dev/null; then
    GXX_CANDIDATE=""
    for candidate in g++-14 g++-13 g++; do
        if command -v "$candidate" &>/dev/null; then
            GXX_CANDITATE="$(command -v "$candidate")"
            break
        fi
    done
    if [[ -n "$GXX_CANDITATE" ]]; then
        ln -sf "$GXX_CANDITATE" "$CONDA_PREFIX/bin/g++-15"
        echo "[SETUP] 已创建 g++-15 -> $(basename "$GXX_CANDITATE") 符号链接"
    else
        echo "[WARN] 未找到可用的 g++，simpler sim 编译可能会失败"
    fi
fi
if ! command -v gcc-15 &>/dev/null; then
    GCC_CANDIDATE=""
    for candidate in gcc-14 gcc-13 gcc; do
        if command -v "$candidate" &>/dev/null; then
            GCC_CANDIDATE="$(command -v "$candidate")"
            break
        fi
    done
    if [[ -n "$GCC_CANDIDATE" ]]; then
        ln -sf "$GCC_CANDIDATE" "$CONDA_PREFIX/bin/gcc-15"
    fi
fi

# ---------- PTOAS 编译器 ----------
if [[ ! -x "$PTOAS_ROOT/ptoas" ]]; then
    echo "[ERROR] ptoas 未找到。请先下载安装："
    echo "  mkdir -p $PTOAS_ROOT"
    echo "  curl -L -o /tmp/ptoas-bin.tar.gz \\"
    echo "    'https://github.com/zhangstevenunity/PTOAS/releases/download/v0.19/ptoas-bin-x86_64.tar.gz'"
    echo "  tar -xzf /tmp/ptoas-bin.tar.gz -C $PTOAS_ROOT"
    echo "  chmod +x $PTOAS_ROOT/ptoas $PTOAS_ROOT/bin/*"
    return 1 2>/dev/null || exit 1
fi
export PTOAS_ROOT
export PATH="$PTOAS_ROOT:$PATH"

# ---------- Simpler 运行时 ----------
if [[ ! -d "$SIMPLER_ROOT" ]]; then
    echo "[ERROR] simpler 目录不存在: $SIMPLER_ROOT"
    return 1 2>/dev/null || exit 1
fi
export SIMPLER_ROOT

# 检查 _task_interface 是否已编译
if ! python -c "from _task_interface import DataType" 2>/dev/null; then
    echo "[WARN] _task_interface 未安装。正在编译安装 simpler..."
    (
        cd "$SIMPLER_ROOT"
        CC=/usr/bin/gcc CXX=/usr/bin/g++ pip install -e . --no-build-isolation
    )
    echo "[SETUP] simpler 编译安装完成"
fi

# ---------- 状态输出 ----------
echo "==========================================="
echo " PyPTO-Lib 开发环境已激活"
echo "==========================================="
echo " Conda env : $CONDA_ENV_NAME"
echo " Python    : $(which python)"
echo " ptoas     : $(ptoas --version 2>&1)  [$PTOAS_ROOT/ptoas]"
echo " SIMPLER   : $SIMPLER_ROOT"
echo " g++-15    : $(command -v g++-15 2>/dev/null || echo 'NOT FOUND')"
echo "==========================================="
echo ""
echo " 快速开始:"
echo "   cd $PYPTO_LIB_ROOT"
echo "   python examples/beginner/hello_world.py -p a2a3sim -d 0"
echo "   python examples/beginner/matmul.py -p a2a3sim -d 0"
echo ""
