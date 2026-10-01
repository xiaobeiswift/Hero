# 青苇渡灯杆与悬灯素材来源

2026-10-01 为 Hero · 渡灯录制作。内置图像生成工具仅以本项目环境图集作为材质与视角参考，生成同一灯杆道具的两个分离组件：空钩木架与纸灯。未采用其他游戏或第三方图片。

原始1774×887 RGBA PNG保持不变，SHA256：d4b07d2502df4966f91ad608773c6ddc351a147b7414f278275b8bc76e3de44e。alpha>16边界：木架(351,42)–(738,846)，灯体含悬绳/小穗(1243,248)–(1405,725)。透明组件间隔充分，运行时分别取区域(343,34,404,821)与(1235,240,179,494)，缓存共享原始贴图。

木架等比高68世界像素，脚底(100,812)固定在原四处位置；悬灯等比高32世界像素，独立四点纹理绕挂环轻摆，挂点不滑动。木架按脚底与人物/房屋排序，其他地区沿用原样式。没有改变碰撞、任务或交互；这是白天已有纸灯的材质改进，不添加昼夜系统或照明玩法。

来源记录说明项目定向原创制作，不承诺排他权利或与其他作品绝无偶然相似，没有引入图库/模型许可。

## 完整生成提示

Use case: stylized-concept
Asset type: a two-component transparent sprite sheet for ONE original village lantern-post prop in Hero / 渡灯录.
Input image: original project environment atlas, STYLE AND CAMERA reference only.
Primary request: make the wooden support and the hanging lantern as TWO SEPARATE isolated components so the game can gently swing only the lantern. Wide canvas with two generous isolated halves and a broad empty transparent gutter. No component crosses the gutter or touches the canvas edge.
LEFT HALF: one slender weathered dark-brown freestanding wooden post with a small cross-arm extending right at its top, a diagonal wood brace and a tiny iron hook near the outer right end. Modest squared foot resting on one small stone footing. The pole is vertical, practical rural joinery and hemp binding. NO lantern attached to this left component, no hanging object or long rope; the hook is visibly empty. Whole post and base visible, upright front three-quarter elevated RPG view.
RIGHT HALF: one separate traditional small warm-amber paper lantern with visible thin bamboo ribs, a simple dark wood cap, a short hanging cord loop at its top and a very small restrained tassel below. Whole loop, body and tassel visible. Soft inner glow painted in the paper, no large external glow halo. Vertical hanging idle pose, same elevated camera and lighting as the post. No support post in this half.
Style: detailed hand-painted ink-edged wood, stone, rope and paper matching the supplied buildings. Natural earthy materials, restrained ochre/brown/amber. Soft daylight. The support will be rendered about66world pixels tall, lantern about30world pixels tall; keep both silhouettes crisp at that scale.
Composition constraints: exactly the two named components, equal-height reference cells but independent component scales are fine. True transparent RGBA background. No floor plane, backdrop, cast shadows, people, plants, extra objects, labels, text, frame/grid lines, logos or watermark. No glossy3D toy or flat vector drawing.

