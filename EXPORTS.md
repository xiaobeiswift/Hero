# 桌面导出与验收

本工程提供 **Linux x86_64、Windows x86_64、macOS Universal（Intel + Apple Silicon）** 导出预设。它们是离线、无账号的单机原型。跨平台导出成功不代表已在目标系统运行验收。

## 固定构建依赖

- Godot **4.6.3.stable.official.7d41c59c4**，标准 GDScript 版本
- 对应的官方 **4.6.3.stable** 导出模板
- Bash、curl、Python **3.11+**，仅用 Python 标准库
- 导出脚本目前在 Linux 构建主机验证；Windows/macOS 可在 Godot 编辑器中使用同一预设

模板取自 [Godot 官方发布页](https://godotengine.org/download/archive/4.6.3-stable/)。安装脚本使用官方服务下载，按 [Godot 官方 SHA-512 清单](https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/SHA512-SUMS.txt) 的固定摘要校验整个文件，然后仅解压桌面所需模板。不会安装到系统目录，也不使用密钥。

## 一次性准备

在工程根目录执行：

```sh
godot --headless --version
bash tools/install-export-templates.sh
```

模板下载约 1.2 GB，缓存于被 Git 忽略的 `builds/template-cache/`，实际桌面模板位于 `builds/export-data/godot/export_templates/4.6.3.stable/`。默认不重复下载。校验失败会停止，不会执行未验证模板。可通过 `HERO_TEMPLATE_CACHE`、`HERO_EXPORT_DATA` 指定构建专用目录。

`licenses/` 中已经随附从同版本引擎提取的 MIT 与第三方许可。更换引擎时，应同时审查版本、模板固定摘要和许可，并重新生成：

```sh
mkdir -p builds/export-config builds/export-cache builds/export-data
XDG_CONFIG_HOME="$PWD/builds/export-config" \
XDG_CACHE_HOME="$PWD/builds/export-cache" \
XDG_DATA_HOME="$PWD/builds/export-data" \
godot --headless --path "$PWD" --script tools/export_licenses.gd -- "$PWD/licenses"
```

## 构建

```sh
# 默认只构建 Linux；每次使用一个新的标签，避免覆盖旧验收证据
python3 tools/export_desktop.py --target linux --label test-linux-001

# 同一份源码快照导出全部桌面目标
python3 tools/export_desktop.py --target all --label checkpoint004
```

可选 `--target windows`、`--target macos`；`--godot /absolute/path/to/godot` 可指定编辑器。脚本严格检查完整引擎版本，版本不匹配会停止。

如果源码位于 Git 工作区，脚本还会记录准确的本地提交 ID，并默认拒绝未提交的游戏代码/资源或构建工具变更。开发试验可显式加 `--allow-dirty-source`，但报告将保留 dirty 标记，不能把它当成已提交的发行版本。下载的纯源码 ZIP 不含 Git 时，仍可构建并以源码 SHA-256 清单标识；脚本不会连接远端或申请认证。

脚本会：

1. 把游戏资源、代码、场景、导出预设和许可复制到独立快照；复制前后校验，源文件在复制期间变化即停止
2. 在独立配置/缓存目录重新导入资源，从同一快照导出所有选定平台
3. 输出未嵌入的 PCK、平台运行程序、压缩发行包、源码 SHA-256 清单、发行包 SHA-256 清单及 JSON 构建报告
4. 拒绝覆盖已有标签；所有产物、日志、临时配置和测试存档保留在 `builds/<标签>/`
5. 为 Linux 单独运行实际 release 可执行文件的 60 帧 headless 启动检查
6. 由 Linux 编辑器分别加载**每个平台实际导出的 PCK**，各执行 25 项资源/游戏流程检查。该检查不是目标平台可执行文件内运行的测试；release 模板不支持 `--script`

任何导入/导出/运行的非零状态、Godot `ERROR` 或 `SCRIPT ERROR` 都会使构建失败，即使 Godot 本身返回 0。构建报告只会把实际完成的步骤记为通过。完整回归测试仍应另外执行 `bash run-tests.sh`。

这是可重复的构建流程，并不承诺 ZIP 元数据、签名时间等逐字节确定性。请用每次输出的 `SOURCE-SHA256SUMS.txt` 和 `SHA256SUMS.txt` 标识确切版本。

## 包含与排除

- 包含：实际游戏脚本/场景、中文字体、图像、声音、字体完整许可、Godot MIT 和第三方许可
- 排除：测试脚本、构建工具、截图、构建缓存、开发文档、Git/编辑器私有数据
- PCK 内保留字体和引擎许可；发行压缩包旁置易读许可与启动说明，不要求玩家使用 Godot 查看
- Linux/Windows 程序与 `Hero.pck` 必须放在一起，不能只分发可执行文件
- macOS 使用 Godot 内置 ad-hoc 签名，不申请 Developer ID、不创建账号、不进行公证；系统首次打开限制仍须在真实 Mac 上验收
- macOS Universal 要求 `rendering/textures/vram_compression/import_etc2_astc=true`；工程已启用。Linux/Windows 保持 S3TC/BPTC 预设
- Windows 原型未作 Authenticode 签名，系统可能显示发行者/信誉提示；这里不宣称已完成发行认证

## 验收范围

`BUILD-REPORT.json` 区分：

- `export`：平台产物是否成功生成
- `native_runtime`：是否实际运行目标系统的程序
- `pack_audit`：导出 PCK 的资源和流程检查
- `graphical_runtime`：图形运行是否由该脚本验证（本脚本不做 GUI 测试）

25 项 PCK 检查覆盖：测试/工具/截图排除、字体/图像/音乐和许可存在、主场景/脚本加载、标题、新游戏、对话、行囊、武学、舆图、战斗行动与撤退、第二地图、本地存档读写。测试存档完全位于该构建的 `<平台>-smoke-data/`，不会读写正常玩家存档。

需要补做的目标系统验收：真实 Windows/macOS 启动、字体渲染、输入、音频、存读档、窗口缩放、关闭与重启、macOS 首次打开行为。仅导出成功不能替代这些检查。

## 手动编辑器导出

若在 Godot GUI 中导出，请把对应模板安装到该编辑器自己的模板目录，然后使用项目的 `export_presets.cfg`。命令行等价操作示例：

```sh
mkdir -p builds/manual/linux
XDG_DATA_HOME="$PWD/builds/export-data" \
XDG_CONFIG_HOME="$PWD/builds/export-config" \
XDG_CACHE_HOME="$PWD/builds/export-cache" \
godot --headless --path "$PWD" --export-release "Linux x86_64" "$PWD/builds/manual/linux/Hero.x86_64"
```

以上手动命令不自动附加发行包旁置许可或进行验收；正式交付优先使用完整脚本。

参考：[Godot 导出流程](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_projects.html)、[Linux 导出](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_linux.html)、[macOS 导出](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_macos.html)
