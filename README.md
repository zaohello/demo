# Demo

此仓库提供在受限或离线环境中快速配置 [KrillinAI](https://github.com/krillinai/KrillinAI) 项目的辅助脚本。

## 脚本功能概览

`scripts/setup_krillinai.sh` 可以完成以下任务：

- 从 Git 仓库、本地目录或离线打包文件中准备项目源代码；
- 创建隔离的 Python 虚拟环境；
- 根据 `requirements.txt` 或 `pyproject.toml` 安装依赖；
- 可选地从本地离线依赖目录安装所需 wheel 包。

## 使用方法

```bash
./scripts/setup_krillinai.sh [选项] [目标目录]
```

常用选项：

- `-s <路径或URL>`：指定项目来源。支持 Git 地址（默认：`https://github.com/krillinai/KrillinAI`）、本地目录或 `.tar.gz/.tgz/.zip` 打包文件。
- `-b <分支>`：当来源是 Git 仓库时指定分支或标签。
- `-p <python>`：指定 Python 解释器，默认 `python3`。
- `-w <目录>`：指定离线依赖目录，脚本将使用 `pip --no-index --find-links` 安装依赖。
- `-h`：查看帮助信息。

目标目录缺省为当前目录下的 `krillinai`，若该目录已存在且非空，脚本会保留其中内容。

### 典型场景

1. **在线环境克隆并安装**
   ```bash
   ./scripts/setup_krillinai.sh
   ```

2. **使用本地归档文件**
   ```bash
   ./scripts/setup_krillinai.sh -s /path/to/KrillinAI.tar.gz /opt/krillinai
   ```

3. **离线安装依赖**
   先准备好包含所有 wheel 包的目录（例如 `/mnt/wheels`），再运行：
   ```bash
   ./scripts/setup_krillinai.sh -w /mnt/wheels /opt/krillinai
   ```

## 激活虚拟环境

脚本完成后，使用以下命令激活虚拟环境：

```bash
source /path/to/krillinai/.venv/bin/activate
```

如需重新安装依赖，可再次运行脚本或手动在虚拟环境中执行 `pip` 命令。
