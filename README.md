# ComfyUI（共享环境）README —— 迁移安全与协作规范

本项目用于在共享服务器上学习与运行 ComfyUI，并确保后续可“低成本、可重复”地迁移到新服务器（云主机）。

请严格遵守下列强制规则，避免任何破坏迁移可持续性的修改。

## 强制规则（必须遵守）

1) 虚拟环境不可迁移/提交
- 禁止提交、打包或迁移 `.venv/` 到任何机器。
- 迁移时在目标机器“重新创建虚拟环境”，再安装依赖。

2) Torch 安装与 CUDA 绑定
- 先安装“与目标 GPU/驱动匹配”的 `torch/torchvision/torchaudio`，再执行 `pip install -r src/requirements.txt`。
- 不要把特定 CUDA 版 `torch*` 固定进锁定清单；如需锁定，请使用不含 `torch*` 的锁定文件（见下文“依赖锁定”）。

3) 模型管理与存储
- 大模型不要混入仓库根目录。推荐把模型统一放到独立路径（如数据盘），并在 `src/models/` 中使用相对软链接指向。
- 禁止把大模型文件提交到版本库或随迁移包无选择地整体打包。

4) 自定义节点规范
- 所有自定义节点必须放在 `src/custom_nodes/`。
- 每个第三方节点必须包含来源与版本信息（新增 `NODE_VERSION.txt` 或 `README.md`，记录 Git 仓库与 commit/版本号）。
- 禁止直接修改 Python 的 site-packages 内的第三方库；必须 fork 或复制到 `src/custom_nodes/<your_node>/` 后再改。

5) 用户数据与工作流
- `src/user/` 下按“用户/项目”分目录管理，避免混放与路径硬编码。
- 导出的工作流/配置必须可移植（避免写死本机绝对路径）。

6) 启停方式统一
- 后台运行一律使用 `comfyui.sh`：保持 `--host`、`--port`、`--multi-user`、`--`（透传参数）兼容。
- 日志输出位置必须为 `comfyui.out`，PID 文件为 `comfyui.pid`，不得随意更改。

7) 端口与访问
- 默认端口 `8188`。如需更改，务必在 README 中更新“端口约定”，并通知其他成员与运维（含云安全组/防火墙）。

8) Python 版本
- 推荐 Python 3.10/3.11，禁止在同一目录混用多个 Python 版本运行。

9) 依赖变更流程
- 如需修改 `src/requirements.txt`，同时生成/更新 `src/requirements.lock.txt`（不含 `torch*`）。
- 在本文“变更记录”中简述变更目的与影响范围。

10) 权限与可执行
- `comfyui.sh` 必须可执行（`chmod +x`）。
- `src/models/` 与 `src/user/` 必须具备读写权限；禁止设置为 777，遵循最小权限原则。

---

## 目录结构约定

- `comfyui.sh`：统一的服务管理脚本（start/stop/restart/status）。
- `comfyui.out`、`comfyui.pid`：日志与 PID 文件（自动生成）。
- `src/`：ComfyUI 源码、依赖清单与项目内容根目录。
  - `src/requirements.txt`：项目依赖（不固定 GPU 版 torch）。
  - `src/requirements.lock.txt`：锁定依赖（不含 `torch*`，可选，见下）。
  - `src/custom_nodes/`：自定义/第三方节点，需记录来源版本。
  - `src/user/`：用户数据与工作流；按“用户/项目”分目录。
  - `src/models/`：模型目录；推荐仅保留软链接或小模型/占位符。

---

## 安装与运行（共享服务器）

1) 准备 Python 虚拟环境
```bash
python3 -m venv "$HOME/ComfyUI/.venv"
source "$HOME/ComfyUI/.venv/bin/activate"
pip install --upgrade pip
```

2) 安装与 GPU 匹配的 Torch（示例：CUDA 12.1）
```bash
# 依据实际 CUDA/驱动选择对应索引： https://pytorch.org/get-started/locally/
pip install --index-url https://download.pytorch.org/whl/cu121 \
  torch torchvision torchaudio
```

3) 安装项目依赖
```bash
pip install -r "$HOME/ComfyUI/src/requirements.txt"
```

4) 启动/停止
```bash
chmod +x "$HOME/ComfyUI/comfyui.sh"
# 启动（多用户模式，监听 0.0.0.0:8188）
"$HOME/ComfyUI/comfyui.sh" start --host 0.0.0.0 --port 8188 --multi-user
# 状态
"$HOME/ComfyUI/comfyui.sh" status
# 停止
"$HOME/ComfyUI/comfyui.sh" stop
```

---

## 迁移到新服务器（推荐流程）

仅迁移“业务资产”，不迁移 `.venv/`。

1) 在老机器打包（排除 `.venv/` 与大临时文件）
```bash
cd "$HOME"
# 推荐打包：代码 + 自定义节点 + 用户数据 + （可选）常用模型
# 模型很大时，可只同步常用模型，其余在新机按需下载

tar --exclude='ComfyUI/.venv' \
    --exclude='ComfyUI/**/__pycache__' \
    -czf ComfyUI_migrate.tgz ComfyUI
```

2) 在新机器解压
```bash
mkdir -p "$HOME"
tar -xzf ComfyUI_migrate.tgz -C "$HOME"
```

3) 在新机器重建环境
```bash
python3 -m venv "$HOME/ComfyUI/.venv"
source "$HOME/ComfyUI/.venv/bin/activate"
pip install --upgrade pip
# 先安装与新机 GPU/驱动匹配的 torch*
# 再安装项目依赖
pip install -r "$HOME/ComfyUI/src/requirements.txt"
```

4) 校验并启动
```bash
"$HOME/ComfyUI/comfyui.sh" start --host 0.0.0.0 --port 8188 --multi-user
```

---

## 依赖锁定（可选，便于复现）

生成“排除 torch* 的锁定清单”，避免 GPU 绑定：
```bash
source "$HOME/ComfyUI/.venv/bin/activate"
pip freeze | grep -vE '^(torch|torchvision|torchaudio)\b' \
  > "$HOME/ComfyUI/src/requirements.lock.txt"
```
使用锁定安装（在已安装与 GPU 匹配的 torch* 之后）：
```bash
pip install -r "$HOME/ComfyUI/src/requirements.lock.txt"
```

---

## 模型路径与软链接建议

- 将大模型集中在独立路径（例如：`/data/models/`）。
- 在 `src/models/` 下创建相对软链接，提升可移植性与清晰度：
```bash
mkdir -p "$HOME/ComfyUI/src/models/diffusion_models"
ln -s ../../../../data/models/diffusion/sd15 \
      "$HOME/ComfyUI/src/models/diffusion_models/sd15"
```

注意：迁移时只需同步独立模型目录（如 `/data/models/`）并保持链接关系即可。

---

## 备份/同步建议

- tar 归档（排除 `.venv/`）：见上文
- rsync 同步（排除 `.venv/` 与缓存）：
```bash
rsync -av --delete \
  --exclude='.venv' \
  --exclude='**/__pycache__' \
  "$HOME/ComfyUI/" user@new-host:~/ComfyUI/
```

---

## 迁移后自检清单

- [ ] `comfyui.sh status` 正常，日志 `comfyui.out` 无明显报错
- [ ] 自定义节点能正常加载（其依赖在新机已安装）
- [ ] 常用工作流在 `src/user/` 可打开并运行
- [ ] 常用模型可被识别并能正常推理
- [ ] 端口/防火墙/安全组已放行

---

## 常见问题（FAQ）

- Torch/CUDA 不匹配导致导入失败
  - 症状：`libcuda.so` 或 `CUDA error` 等。
  - 处理：卸载 `torch*` 后，按新机 CUDA/驱动重新安装对应版本。

- 端口被占用
  - 修改启动端口：`./comfyui.sh start --port 8288 --multi-user`

- 自定义节点缺依赖
  - 在虚拟环境中补装：`pip install <package>`；完成后可更新 `requirements.lock.txt`（排除 `torch*`）。

- 缺少系统依赖（如 ffmpeg）
  - 由管理员在系统层安装（Ubuntu 示例）：`sudo apt-get install ffmpeg`

---

## 变更记录（请维护）

- YYYY-MM-DD：新增/修改依赖；原因；影响范围；是否更新 `requirements.lock.txt`。
- YYYY-MM-DD：新增自定义节点 `<name>`；来源仓库与 commit；使用说明链接。

---

## 附：脚本用法速查（`comfyui.sh`）

```bash
# 启动（可覆盖 host/port 并启用多用户）
./comfyui.sh start --host 0.0.0.0 --port 8188 --multi-user
# 停止
./comfyui.sh stop
# 重启
./comfyui.sh restart --host 127.0.0.1 --port 8288
# 状态
./comfyui.sh status
# 透传 ComfyUI 原生命令行参数
./comfyui.sh start -- --help
```
