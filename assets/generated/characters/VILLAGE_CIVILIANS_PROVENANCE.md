# 青苇渡平民人物素材来源

2026-10-01 为 Hero · 渡灯录制作。三名原创成年村民为挑夫、提篮居民、药铺伙计；只使用本项目既有绘制村中人物图集作为风格/尺度参考，不复制其中已命名人物的身份或衣饰。

内置图像生成工具产出2170×725 RGBA源图，源图保持原样。通过自行编写的Blender正交透明卡片渲染，统一0.32投影比例，将各自测量脚底对齐至每格(128,241)，整理为768×256的三格透明图集。不是行走帧；身体保持闲置，只有既有世界的地面阴影表现。

- 源图SHA256：206147cd494abae013ee7a6567b38742180c81c5a1c2f82acc9a73a6e5a65c7c
- 运行时图集SHA256：0cd4b146769f216afc257363cb33b8eb5e6d7afd059011d006c19ffc7e1846e7
- 每格256×256；排列：挑夫、提篮居民、药铺伙计
- 默认游戏绘制格72像素；三个AtlasTexture缓存一次后复用
- 原图、测量记录、Blender脚本和场景保留于制作工作区；当前仓库发布运行时图集、提示及验证记录
- 逐格像素与对应Blender单帧一致；alpha>16的前景至少离格边4像素；无相邻人物串图

这些是本项目定向生成的原创设计，记录制作过程，不承诺排他的权利或与任何其他作品绝无偶然相似。没有引入第三方人物/图库/模型许可。

## 原始生成提示

Use case: stylized-concept
Asset type: original transparent three-person NPC idle sprite sheet for Hero / 渡灯录.
Input image: project-owned village cast, STYLE AND SCALE REFERENCE ONLY. Create THREE NEW adult civilian villagers; do not copy the faces or costumes of the named characters shown in the reference.
Composition: wide3-column sheet, one complete full-body figure centered in each equal column, front-facing with a restrained slight three-quarter turn, all at exactly the same natural adult scale and foot baseline. Generous transparent space around hair, hands, basket and boots. Whole bodies and feet visible. True transparent background.
Left figure: an adult river porter in his40s, weathered friendly face, tied dark hair, russet-brown short outer tunic over faded linen, dark trousers, cloth calf wraps and sturdy shoes. A modest tied cloth bundle/satchel hangs over one shoulder. Relaxed working stance, no weapon.
Middle figure: an adult village woman in her50s, hair in a plain bun, muted sage/grey-green long jacket with modest ochre waist sash, dark trousers and cloth shoes. Holds a small woven market basket at one side. Calm ordinary everyday pose, no weapon.
Right figure: an adult male apothecary assistant in his30s, short tied dark hair, plain blue-grey robe with a pale canvas work apron, dark trousers and boots. Carries a small closed wooden medicine box or wrapped herb packet naturally at waist height. Distinct face and silhouette from the other two, no weapon.
Style: detailed hand-painted2D wuxia RPG sprites matching the reference's ink-edged cloth/material rendering, restrained earthy color palette and realistic adult proportions. Clear readable silhouettes at small gameplay scale. Soft even daylight, natural anatomy, worn practical clothing. No chibi, blocky dolls, glossy3D skin or photoreal faces.
No ground, floor shadows, scenic backdrop, frames, labels, pose names, text, logos, health bars or UI. Do not add extra people. Exactly three isolated original civilian characters.
