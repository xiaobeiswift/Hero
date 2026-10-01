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

本项目原创生成的角色纹理，通过自行编写的Blender分层卡片动画渲染为32帧四向步态。此为最初探索主角批次；其后村中人物、沈青同行及主角/蒲横战斗素材的范围另列于本目录各来源记录。来源、输入链、动画限制与当前仅发布运行时素材的范围，见 assets/generated/characters/PAINTED_TRAVELER_PROVENANCE.md。

### 青苇渡主要人物闲置姿态（2026-10-01）

四位村中人物及沈青的四向预备素材，由本项目原创图像经Blender透明卡片定尺渲染。完整提示、来源范围与当前闲置姿态限制见 assets/generated/characters/PAINTED_VILLAGE_PROVENANCE.md。角色身份与原有任务不变，不将方向闲置图说成行走动画。

### 绘制战斗角色与渡口背景（2026-10-01）

主角/蒲横六姿态及渡口月夜背景为本项目原创生成素材；人物经Blender透明卡片整理。准确提示、输入链、固定锚点及使用范围分别见 assets/generated/characters/PAINTED_COMBAT_HERO_PROVENANCE.md、PAINTED_COMBAT_PUHENG_PROVENANCE.md 和 assets/generated/environment/FERRY_BATTLE_PROVENANCE.md。渡口绘画保持原始像素，只在引擎中等比定位与叠加水光。

### 沈青交锋支援（2026-10-01）

本项目沈青方向图作为唯一身份参考，原创生成四种支援姿态，再经Blender同尺度UV卡片整理。来源、完整提示、透明边缘检查、脚底与仅沈青生效的范围见 assets/generated/characters/PAINTED_COMBAT_SHEN_PROVENANCE.md。

### 青苇渡水面材质（2026-10-01）

原始日间青绿水纹由独立文字提示生成，未引用其他图像。原图保持不变，游戏用既有池塘/河道多边形和等比UV取样；原始提示、摘要和静态材质限制见 assets/generated/environment/WATER_PROVENANCE.md。

### 旧木甲板与小舟（2026-10-01）

两个独立文字提示生成的原创PNG保留原始像素；甲板按原矩形等比取样，小舟按实测透明裁切取样。准确提示、尺寸、摘要与使用范围见 assets/generated/environment/FERRY_PROPS_PROVENANCE.md。

### 青苇渡平民人物（2026-10-01）

三名原创成年村民由项目风格参考生成，再经Blender透明卡片同尺度整理；只替换两位背景居民和沈青同行时的药铺伙计。原始提示、摘要、脚底与静态闲置范围见 assets/generated/characters/VILLAGE_CIVILIANS_PROVENANCE.md。

### 青苇渡告示牌（2026-10-01）

项目建筑图集仅作风格与视角参考，独立生成木框瓦顶告示牌；原始透明PNG不改动，运行时等比裁切并按脚底排序。完整提示、摘要与使用范围见 assets/generated/environment/NOTICEBOARD_PROVENANCE.md。

### 旧渡口布棚（2026-10-01）

项目环境图集仅作材质与视角参考，独立生成布棚，保留透明原图并由引擎缓存裁切。来源、摘要、脚底与静态/遮挡范围见 assets/generated/environment/CAMP_SHELTER_PROVENANCE.md；篝火仍用项目原创程序动画。

### 青苇渡竹丛（2026-10-01）

项目环境图集仅作风格参考，原创生成独立竹丛，PNG原样保存；缓存纹理与小幅四边形变形保留根部位置。完整提示、原始尺寸、摘要与整丛轻摆限制见 assets/generated/environment/BAMBOO_PROVENANCE.md。

### 听雨茶肆桌凳（2026-10-01）

项目环境图集作为材质/视角参考，独立生成一组桌凳与茶器，透明原图保持不变。裁切、脚底、原始提示和范围见 assets/generated/environment/TEA_TABLE_PROVENANCE.md。

### 青苇渡木灯杆（2026-10-01）

本项目环境图集作风格参考，独立生成木架与悬灯两个组件，透明原图不修改。引擎缓存裁切并只让灯体绕挂环摆动；原始提示、摘要和范围见 assets/generated/environment/LANTERN_POST_PROVENANCE.md。
