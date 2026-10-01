# 2026-10-01 · 青苇渡表现验收

## 已验证的源码

第一轮场景与动作对应本地提交 `8cef96e`。源码可直接由 Godot 4.6.3 打开；本轮没有修改既有发行压缩包。

- 实际原生引擎绘制截图70–72：原绘制建筑、树木、连续苔土、门牌与NPC姓名
- 实际接受战斗操作截图74–78：突进、剑光、格挡、治疗与最后一击
- 截图73和短片中的探索部分，通过 Input.action_press/release 驱动真实移动逻辑，含方向改变与同行跟随
- 短片共384帧、1280×800、30FPS固定时间步、12.8秒；H.264文件2,356,862字节，无音轨
- MP4 SHA256：`56996478e56674378a67a1ad07613cbb0b9b7d43568afe3b9175b33a0572e769`
- Godot Movie Maker原始AVI通过ffmpeg编码，没有添加虚构场景或补间画面；已检查方向移动、角色分离、突进/返回与技能/格挡/治疗接触帧

## 限制

这是准备好的演示场景，不是从新档人工连续通关。演示人为延长切磋对象气血以展示招式，最后另设1点气血展示收招；伤害数字仍取自每次真实规则结算。保存被演示适配器禁用，不接触正常玩家存档。

云端llvmpipe软件渲染录制耗时119秒；固定时间步影片不证明该机器实时达到30FPS。音频使用Dummy，未做听感验证。原生GUI仅在Linux环境使用，未据此声称Windows/macOS运行验证。

角色目前为程序绘制的过渡美术，仍需与场景统一；同一垂柳重复明显，水面与远景仍是早期绘制。绘制方向角色与Blender动画实验在继续，不把未集成候选素材列为完成。

## 后续小修

击中时气血条现按实际伤害/治疗量在0.16秒内变化，最终再同步升级、落败恢复等规则结果。58项界面检查覆盖重叠伤害、治疗上限、落败归零、升级恢复、连点及新战斗取消旧补间；上一短片仍是8cef96e，因此不把它当作新增气血条同步的视觉证据。88–90已另用原生Godot实际接受招式后拍摄，确认治疗阶段中央与侧栏共同显示155/180。


## Painted Shen follow pass · 2026-10-01 16:22 UTC

The existing project-original Shen directional art is now a deterministic Blender cutout walk atlas. Eight frames per direction contain independent boot contacts; torso motion remains restrained. No whole-character mirror switches the satchel side. The atlas has 32 measured 256px cells and the same (128,241) foot anchor as the protagonist.

The follower uses cached atlas crops. Reachable trailing targets provide lateral separation; island-specific placement is unchanged. Foreground willows fade for either party member. The full source suite passed, including all prior traversal/save/quest tests. Screenshots 108–112 were rendered and inspected at game scale.

Motion evidence: Hero-painted-party-walk.mp4, 120 frames, 4.000 seconds, 1280×800, H.264, 2,691,361 bytes. SHA-256: b3541f14dea65f6b60d82891160debcf96076d845c128b89cc4b454437ac1f30. Godot Movie Maker used fixed 30 FPS simulation, taking 18 seconds to record (20 seconds with startup). This is a prepared in-engine animation preview, not a real-time frame-rate benchmark or a clip from released 0.0.11.

Limits: no fully articulated upper-body/cloth rig; Tang Qi and combat actors remain procedural. No claim of fresh full-game manual completion.
