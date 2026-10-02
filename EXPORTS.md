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
python3 tools/export_desktop.py --target all --label v0.0.17 --sequential-platforms
```

可选 `--target windows`、`--target macos`；`--godot /absolute/path/to/godot` 可指定编辑器。脚本严格检查完整引擎版本，版本不匹配会停止。

如果源码位于 Git 工作区，脚本还会记录准确的本地提交 ID，并默认拒绝未提交的游戏代码/资源或构建工具变更。开发试验可显式加 `--allow-dirty-source`，但报告将保留 dirty 标记，不能把它当成已提交的发行版本。下载的纯源码 ZIP 不含 Git 时，仍可构建并以源码 SHA-256 清单标识；脚本不会连接远端或申请认证。

脚本会：

1. 把游戏资源、代码、场景、导出预设和许可复制到独立快照；复制前后校验，源文件在复制期间变化即停止
2. 在独立配置/缓存目录重新导入资源，从同一快照导出所有选定平台
3. 输出未嵌入的 PCK、平台运行程序、压缩发行包、源码 SHA-256 清单、发行包 SHA-256 清单及 JSON 构建报告
4. 拒绝覆盖已有标签；最终产物、源码、日志、临时配置和测试存档保留在 `builds/<标签>/`。仅显式顺序模式会处理本次新建且已核验的外平台临时输出
5. 为 Linux 单独运行实际 release 可执行文件的 60 帧 headless 启动检查
6. 由 Linux 编辑器分别加载**每个平台实际导出的 PCK**，各执行 761 项资源/游戏流程/表现检查。该检查不是目标平台可执行文件内运行的测试；release 模板不支持 `--script`
7. 把本次外置 PCK 测试驱动保存为 `builds/<标签>/smoke_export.gd`，每个平台使用同一副本，并在报告记录其 SHA-256 与预期检查数；该驱动不进入发行 PCK 或压缩包

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

0.0.16原包存在探索中系统关窗在保存失败时仍退出的问题；Windows/Linux最小PCK热修复已发布为 [v0.0.16.1](https://github.com/xiaobeiswift/Hero/releases/tag/v0.0.16.1)，基于冻结0.0.16且仅修改关窗保护。它已通过原761项PCK回归、专项流程和精确原Linux引擎的真实窗口验收，不含0.0.17新内容；Windows原生仍未测，macOS不提供直接PCK替换。未安装补丁或使用macOS时，应通过Esc → 暂别江湖 → 保存并离开。原0.0.16归档未修改，安装前备份及回滚步骤在修复包内。

当前外置驱动为761项：保留此前737项并补充本轮告示/布棚/竹丛/茶桌/悬灯资源与锚点、真实阅读/提示避让；此前阶段覆盖绘制水面/木栈台/小舟/三名平民资源、旧地形通行、探索缩放键盘与菜单、独立偏好持久化、固定HUD、交互与战斗门控、药铺身份和交锋页脚通知。计数是导出完整性回归，不代表人工游玩质量或性能。

`BUILD-REPORT.json` 区分：

- `export`：平台产物是否成功生成
- `native_runtime`：是否实际运行目标系统的程序
- `pack_audit`：导出 PCK 的资源和流程检查
- `graphical_runtime`：图形运行是否由该脚本验证（本脚本不做 GUI 测试）

历史595项阶段的PCK检查保留此前412项覆盖（存档版本断言随当前格式升级为 schema8）。新增183项验证沈青两种照护结局/原草案确认/实战支援和轻功教学/碰撞/拾遗/安全回程；较早109项验证手记存储/恢复界面与人物图集；导出测试在操作前检查隔离路径。其余历史覆盖如下。最早37项为：测试/工具/截图排除、字体/图像/音乐和许可存在、主场景/脚本加载、标题、新游戏、对话、行囊、武学、舆图、战斗行动与撤退、第二与第三地图、本地存档读写、三印机关、文书线索、采集及修桥碰撞。

后续 140 项覆盖：门派与同行规则/界面模块保留，三派实战验艺、实际本门考法、暂缓领奖与重载、准确晋升收益及重复领取保护，未验艺胜利的重试与撤退，唐栖工册任务的两种结局、跨区寻物、暂缓决策和邀请、一次性经验/分支材料、任务日志、同行册与快捷键、后招募沈青、无消耗换人、驻地身份更新、战中换人限制、唐栖实际协击回气及同行身份存读档。

此前126项阶段覆盖：六个新模块及控制器保留，三派共六门进阶武学的实际研习、2/3 考绩定价、两次江湖复命、重复或余额不足时不扣费、不自动换装、第四招式快捷键、战中学习/换装限制、蓄锋与卸劲的实际回合消耗和界面数值、招式/考绩/复命持久化；雾竹坡第四地图的入口前置、八个地标与矢量地形模块、舆图目标、雨痕读取、修亭通行的材料事务、营地调息、守令使三阶段的减伤/重击防守/回息增伤、撤退重试、实际胜利、鸣钟结局的一次性收益与日志、schema8 本地存读档、危险落点修复及返回霜桥。

测试通过场景按钮和输入派发运行；为聚焦导出资源集成，较晚章节的前置状态由驱动配置。PCK 集成检查只完整走雾竹坡的修亭通行与鸣钟结局，三种通行和两种结局的组合仍由完整回归另测，不能把本检查当作从新游戏开始的完整旅程或图形验收。

测试存档完全位于该构建的 `<平台>-smoke-data/`，不会读写正常玩家存档。

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


## 后续构建的临时平台工作区

可选 `--transient-platforms` 只作用于一个全新的构建标签。默认行为不变，已有版本目录一律拒绝覆盖。此选项把未压缩的平台程序、PCK与macOS检查副本放到 `builds/<标签>/transient/`；版本化最终压缩包、完整源码快照、SHA256清单、原始日志、测试存档和后续GUI截图/报告继续保存在该版本目录。

新增 `verify_export_archives.py` 会逐项比较压缩包内成员与实际未压缩文件，包括Linux/Windows的PCK、macOS应用内文件和审计用PCK。构建完成时必须通过，生成ARCHIVE-VERIFICATION.json；损坏包、错误成员、缺失PCK、越界路径与符号链接重定向均会拒绝。该工具只读取，绝不删除文件，也不证明原生进程已关闭。

每个新临时构建有TRANSIENT-WORKSPACE.json。只有在最终包散列和成员再次核对、约定的原生验证完成、实际游戏进程已关闭且发布方不再读取临时文件后，才可单独处理其中标明的 `transient/` 与 `source/.godot/`。单独使用此标记时脚本不自动清理；其他源码、存档、日志、截图、最终包和所有旧版本目录均不在该范围。临时程序删除后，可从原版本压缩包解出逐字节相同的程序/PCK继续复验。

可随时在未清理的构建上执行只读复验：

```sh
python3 tools/verify_export_archives.py builds/v0.0.16
```

真正需要节省空间的开发预检可以仅导出PCK再运行外置驱动，不必先重复创建一套完整Linux程序/源码副本。任何预检都不能替代最终平台压缩包、原生GUI与确切来源验收。

## 空间受限时的顺序导出

`--sequential-platforms` 隐含临时平台目录，并按macOS → Windows → Linux构建。Mac/Windows每个平台的导出和实际PCK审计进程返回后，先逐成员与最终压缩包比较，保存绑定源码提交、源码清单和压缩包摘要的 `ARCHIVE-MEMBERS-<平台>.json`。只有通过后才处理本次进程刚创建的对应临时输出；Linux始终保留给后续图形验证。代码要求新构建所有权标记、相同进程及固定目录，不能借此处理旧版本或任意路径。

完成报告记录成员清单摘要；即使临时输出已处理，`verify_export_archives.py`仍会重新读取压缩包的每个文件，与此前已经对照实际输出的成员清单比较。记录缺失、摘要/来源不同、成员变化或归档PCK缺失都拒绝。验证工具自身始终只读。最终压缩包、源码、所有清单、日志、截图及存档资料不清理。

根据0.0.16实际文件，三份压缩包合计约239MB；未压缩Linux109MB、Windows142MB、macOS应用224MB，官方Mac模板完整解压约385MB。顺序模式预检要求至少1,100MiB可用空间，再按超过53MiB的源码增长增加预算。每个平台前另检查900/460/420MiB门槛，保留至少192MiB的保守余量；不足时给出字节差额并停止，不自行删除其他资料。这是基于当前素材规模的保守空间策略，不是跨机器磁盘峰值保证。共享主机在构建途中仍可能发生其他空间变化。

当前新增流程已通过合成临时文件处理、篡改、来源与低空间检查，并只读复验旧版真实三平台归档；首次新的三平台顺序导出和原生验收另行记录，不能从工具单测宣称发行完成。
