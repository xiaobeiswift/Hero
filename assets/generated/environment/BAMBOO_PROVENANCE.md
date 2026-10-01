# 青苇渡竹丛素材来源

2026-10-01 为 Hero · 渡灯录原创生成。唯一输入为本项目建筑/垂柳图集，只作材质与视角参考；内置图像生成工具独立绘制竹丛，未引用外部游戏、第三方图库或植物照片。

原始1286×1223 RGBA PNG保持不变，SHA256：2886622e4116bd011c0862f0862fc7f67e589ca02a019c57d14a2a16c27e4387。alpha>16前景边界(73,10)–(1260,1191)，位于画布内，没有截断右侧叶片；使用(65,2,1204,1198)透明裁切区域，局部根部(485,1176)。运行时按原始PNG尺寸计算UV，等比缩放到132或146世界像素高，原图没有改色或去除透明RGB。

青苇渡三个既有竹丛使用缓存贴图和四点图形；较小丛使用水平镜像产生变化。上下顶点作微小反向偏移，让根部锚点在整段摆动中固定。是整丛轻摆，不声称逐叶骨骼动画。其他地区保留原绘制方式，碰撞与交互点不变。

素材缓存/UV/镜像摆动根部/有效四边形与通行检查见测试。实际性能诊断若完成，以单独记录为准，不从素材形式推断帧率。

这是项目定向生成的原创设计；来源记录不承诺排他的权利或与任何作品绝无偶然相似，没有引入第三方图库/模型许可。

## 完整生成提示

Use case: stylized-concept
Asset type: one original transparent bamboo clump for the top-down Chinese wuxia RPG Hero / 渡灯录.
Input image: original project environment atlas, STYLE AND CAMERA reference only. Produce a new bamboo plant cluster, no copied buildings or willow tree.
Subject: a small natural clump of six to eight slender jointed green bamboo stems growing from one compact irregular base. Different heights, sparse lower culms and airy overlapping sprays of narrow pointed leaves in the upper half. Some leaves olive green, others softly lit sage; readable gaps between stems and leaf sprays. Slightly asymmetrical natural growth, tallest cane on the left-middle, canopy leaning gently right. No flowers or fruit. A few fallen leaves at the tight root base, no broad soil patch.
Camera/composition: fixed elevated orthographic RPG angle matching the reference. Entire clump, leaf tips and root base visible with generous transparent margins. Roughly as wide as tall or a little taller; foliage should fit within one compact asset and read at about150world pixels high. Roots centered at lower edge, no pot. Single isolated clump, not a forest wall or sheet of variants.
Style/material: hand-painted ink-edged botanical game art, nuanced leaf clusters and bamboo node texture, restrained matte sage/olive/forest greens. Soft natural daylight, no dramatic backlight or gloss. Match the buildings' crafted painted style while remaining legible at small size.
Output: genuine transparent RGBA cutout. No floor shadow, scenery, people, buildings, labels, text, logos, UI, neon outline or baked checkerboard.

