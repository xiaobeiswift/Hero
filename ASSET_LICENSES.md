# 素材与依赖说明

- **地形、界面、战斗场景及部分角色**：本工程 GDScript 原创程序绘制；青苇渡环境与探索主角的绘制素材另见下列条目，见 `scripts/world.gd`、`scripts/battle_art.gd`、`scripts/main.gd`
- **river_theme.wav、chime.wav**：为本工程原创合成的拨弦背景音乐及提示音，没有使用外部采样或既有录音
- **标题背景图**：独立文字提示生成，详见 `assets/generated/ART_PROVENANCE.md`，未使用参考游戏截图或第三方图像作为输入
- **人物对话头像**：独立文字提示生成，原始透明图集与完整来源记录位于 `assets/generated/characters/`，未使用第三方角色图像作为输入
- **NotoSansSC.otf**：来自 Noto Sans CJK SC，SIL Open Font License 1.1；完整随附许可证位于 `assets/fonts/LICENSE.txt`
- **Godot**：运行依赖 Godot Engine 4.6.x（MIT）。当前源码交付不含引擎二进制；发行包导出时须保留引擎许可证与第三方许可

游戏采用通用的探索、任务、队友、装备和回合制玩法，项目名称为 Hero · 渡灯录。


### 青苇渡环境（2026-10-01）

原创生成的建筑/垂柳图集与苔土地表，原始PNG未修改。来源、提示与具体使用限制见 assets/generated/environment/ART_PROVENANCE.md 与 GROUND_PROVENANCE.md。运行时只做裁切、定位和透明混合，不引用其他游戏素材。

### 绘制探索主角（2026-10-01）

本项目原创生成的角色纹理，通过自行编写的Blender分层卡片动画渲染为32帧四向步态。仅探索主角已接入，其他NPC、同伴和战斗角色尚未替换。来源、输入链、动画限制与当前仅发布运行时素材的范围，见 assets/generated/characters/PAINTED_TRAVELER_PROVENANCE.md。
