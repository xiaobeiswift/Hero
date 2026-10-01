# 旧渡口布棚素材来源

2026-10-01 为 Hero · 渡灯录制作。内置图像生成工具仅用本项目环境图集作为材质与视角参考，独立绘制旧帆布、木杆、麻绳和卷席构成的小布棚。未采用外部游戏或第三方图片。

原始1536×1024 RGBA图像不修改，SHA256：63e0f32f6204842f09e0a4f929b71171af461e4b85dbe2652208931ab902728f。角落alpha为0；alpha>16前景范围为(65,56)–(1503,980)。部分完全透明像素保留深褐RGB，不把这些不可见RGB误当成背景或另外抠除。缓存裁切区域(57,48,1455,941)，脚底(727,932)，等比绘制108世界像素宽，定位于原营地(1339,735)。

篝火保留原来的独立程序动画；布棚本身为静态绘画，按脚底排序。主角或同行人走到棚后时画面变淡以保留辨识；此为可见性变化，不改变地形、交互或任务。两种材质开关的对照只用作本版本视觉检查，不宣称性能提升。

这些是项目定向生成的原创设计；制作记录不承诺排他的权利或与任何作品绝无偶然相似。没有引入第三方图库/模型许可。

## 原始提示

Use case: stylized-concept
Asset type: one original transparent small riverside shelter prop for Hero / 渡灯录.
Input image: original project building atlas, used only as a painted material, scale and elevated RPG-camera reference. Make a new humble canvas shelter, not one of the pictured buildings.
Subject: a low practical A-frame travel tent or open lean-to shelter made of weathered muted olive-ochre canvas over two simple dark wooden support poles. Front opening is partly rolled back, showing a dark sheltered interior and a single rolled straw sleeping mat. Tied hemp rope, a small patch in the cloth and creases show daily use. One small folded cloth bundle rests just inside; no people, weapons, banners, flags or extra surrounding structures. No fire; the game's existing separate campfire supplies that element.
Composition: isolated single shelter, gently elevated orthographic three-quarter front view, front opening facing down-left and right canvas side visible. Wider than tall, ground footprint width about1.6times the full height. Whole canvas, ropes and feet visible with transparent margin; no crop. Fixed ground baseline, no large cast shadow, no ground patch or background scenery.
Style: fine hand-painted ink-edged fabric and aged timber matching the supplied buildings, readable material folds and a clear silhouette at about100pixels wide. Restrained sage/olive/ochre colors and soft natural daytime light. Natural practical construction, no modern camping hardware, no glossy3D toy look, no flat vector triangles, no photographic texture, no neon fringe.
Output: one complete transparent RGBA cutout, no text, labels, logos, UI or extra props.

