#!/usr/bin/env bash
set -euo pipefail

REPO_URL_DEFAULT="https://github.com/krillinai/KrillinAI"
PYTHON_BIN="${PYTHON_BIN:-python3}"
BRANCH=""
SOURCE="${REPO_URL_DEFAULT}"
WHEEL_DIR=""

die() {
  echo "错误：$*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
用法：setup_krillinai.sh [选项] [目标目录]

选项：
  -s <路径或URL>  指定项目来源（默认：https://github.com/krillinai/KrillinAI）。
                   可以是 Git 仓库、打包文件（.tar.gz/.tgz/.zip）或本地目录。
  -b <分支>        从 Git 仓库克隆时指定分支或标签。
  -p <python>      指定用于创建虚拟环境的 Python 解释器（默认：python3）。
  -w <目录>        指向包含 Python 离线依赖包的目录，安装时将使用 --no-index。
  -h               显示本帮助并退出。

目标目录默认为 ./krillinai。
USAGE
}

while getopts ":s:b:p:w:h" opt; do
  case "${opt}" in
    s)
      SOURCE="${OPTARG}"
      ;;
    b)
      BRANCH="${OPTARG}"
      ;;
    p)
      PYTHON_BIN="${OPTARG}"
      ;;
    w)
      WHEEL_DIR="${OPTARG}"
      ;;
    h)
      usage
      exit 0
      ;;
    :)
      die "选项 -${OPTARG} 需要参数。"
      ;;
    ?)
      die "未知选项 -${OPTARG}，使用 -h 查看帮助。"
      ;;
  esac
done
shift $((OPTIND - 1))

TARGET_DIR="${1:-krillinai}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "未找到必需命令 '$1'。"
}

require_cmd "${PYTHON_BIN}"

prepare_target() {
  local source="$1"
  local target="$2"

  local target_exists=false
  if [ -d "${target}" ]; then
    if [ "$(ls -A "${target}")" ]; then
      echo "目标目录 ${target} 已存在并包含内容，跳过拉取源代码。"
      return
    fi
    target_exists=true
  fi

  if [[ "${source}" == *"://"* || "${source}" == git@* || "${source}" == *.git ]]; then
    require_cmd git
    if [ "${target_exists}" = true ]; then
      rmdir "${target}" 2>/dev/null || rm -rf "${target}"
    fi
    echo "从 ${source} 克隆项目到 ${target}..."
    git clone "${source}" "${target}"
    if [ -n "${BRANCH}" ]; then
      (cd "${target}" && git checkout "${BRANCH}")
    fi
    return
  fi

  mkdir -p "${target}"

  if [ -d "${source}" ]; then
    require_cmd tar
    echo "从本地目录 ${source} 复制项目..."
    (cd "${source}" && tar cf - .) | (cd "${target}" && tar xf -)
    return
  fi

  if [ -f "${source}" ]; then
    local temp_dir
    temp_dir="$(mktemp -d)"
    case "${source}" in
      *.tar.gz|*.tgz)
        require_cmd tar
        echo "从归档文件 ${source} 解压项目..."
        tar -xzf "${source}" -C "${temp_dir}" || die "解压 ${source} 失败。"
        ;;
      *.zip)
        require_cmd unzip
        echo "从压缩包 ${source} 解压项目..."
        unzip -q "${source}" -d "${temp_dir}" || die "解压 ${source} 失败。"
        ;;
      *)
        rm -rf "${temp_dir}"
        die "不支持的归档格式：${source}。仅支持 .tar.gz/.tgz/.zip。"
        ;;
    esac

    shopt -s dotglob
    local entries=("${temp_dir}"/*)
    if [ ${#entries[@]} -eq 1 ] && [ "${entries[0]}" = "${temp_dir}/*" ]; then
      shopt -u dotglob
      rm -rf "${temp_dir}"
      die "归档 ${source} 为空或未包含文件。"
    fi

    if [ ${#entries[@]} -eq 1 ] && [ -d "${entries[0]}" ]; then
      echo "提取压缩包内的顶层目录 ${entries[0]}..."
      cp -a "${entries[0]}"/. "${target}/"
    else
      cp -a "${temp_dir}"/. "${target}/"
    fi
    shopt -u dotglob
    rm -rf "${temp_dir}"
    return
  fi

  die "无法识别的来源：${source}。请提供有效的目录、归档文件或 Git 仓库地址。"
}

prepare_target "${SOURCE}" "${TARGET_DIR}"

cd "${TARGET_DIR}"

if [ ! -d ".venv" ]; then
  echo "创建虚拟环境..."
  "${PYTHON_BIN}" -m venv .venv
else
  echo "虚拟环境已存在，跳过创建。"
fi

# shellcheck disable=SC1091
source .venv/bin/activate

if [ -n "${WHEEL_DIR}" ]; then
  if compgen -G "${WHEEL_DIR}/pip-*.whl" >/dev/null; then
    pip install --upgrade pip --no-index --find-links "${WHEEL_DIR}"
  else
    echo "提示：离线目录 ${WHEEL_DIR} 中未找到 pip wheel，跳过 pip 升级。"
  fi
else
  pip install --upgrade pip
fi

install_with_wheel_opts() {
  if [ -n "${WHEEL_DIR}" ]; then
    pip install --no-index --find-links "${WHEEL_DIR}" "$@"
  else
    pip install "$@"
  fi
}

if [ -f "requirements.txt" ]; then
  echo "安装 requirements.txt 中的依赖..."
  install_with_wheel_opts -r requirements.txt
elif [ -f "pyproject.toml" ]; then
  echo "检测到 pyproject.toml，安装项目本身..."
  install_with_wheel_opts -e .
else
  echo "未找到 requirements.txt 或 pyproject.toml，跳过依赖安装。"
fi

echo "配置完成。使用 'source ${TARGET_DIR}/.venv/bin/activate' 激活虚拟环境。"
