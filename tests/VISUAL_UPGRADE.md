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


## Matched painted duel · 2026-10-01 17:29 UTC

Hero and Pu Heng use separate, direction-correct key-pose atlases. The rival is selected only for three exact Pu Heng identity strings; other enemies retain their existing renderer. Measured Blender UV outlines remove neighboring-pose contamination without repainting the source. The initial wrong-facing and clipped-boot candidates were rejected before integration.

The complete runtime regression suite passed. Actual engine images 121–128 include outgoing contact, incoming counter, guard, healing, kneel and the real result modal. The final prepared scenario starts a level 3 character at 70/124 HP with the standard 64 HP sparring rival. Attack, guard, medicine and a finishing skill then resolve through the ordinary controller. No mid-battle HP edits are used in the final recording.

Final clip: Hero-painted-duel.mp4, 189 frames, 6.300 seconds, 1280×800, H.264, 940,352 bytes. SHA-256: fd527e07bc2fadd6d7c8ab0c388335ee2f77337bc15e202596b60184220d4e1f. Fixed 30 FPS Movie Maker simulation took 12 seconds to record (13 seconds including startup). This is animation evidence, not a real-time performance benchmark or footage from released 0.0.12.

Limits: key-pose artwork with procedural stage movement, not fully articulated skeletal animation; other opponents and battle companions are not yet all painted. No new manual full-story completion claim.

## Painted ferry stage · 2026-10-01 17:51 UTC

Actual engine captures129–136 show the original painted ferry landing with normal accepted attack, counter, guard, healing, finishing skill and result flow. The prepared scene uses the same ordinary64HP rival and level3 protagonist as the prior duel. Actor anchors and battle rules are unchanged. The painting is projected onto the original938×356 fighting area, with its measured dock surface behind the feet. The full938×568Control also contains the lower commands and is deliberately not used as the painting aspect-cover target. A soft footer transition prevents a raw image edge crossing the battle text. Only Qingwei encounters use this plate; other regional styles retain their distinct stages. This is static scenery with8subtle live water highlights, not a fully animated landscape.

Native wall-clock diagnostic: Godot4.6.3 editor, OpenGL Compatibility, Mesa25.0.7, llvmpipe LLVM19.1.7,1180×812native window. Same painted actors/HUD and same viewport; background toggle in ABBA order,4seconds each, no Movie Maker. Results in ferry_performance_results.json: procedural13.29FPS/69calls, painted40.14FPS/46.71calls, painted37.73FPS/46calls, procedural37.14FPS/66calls. The first sample is much slower; this short noisy shared-host sample does not establish a stable FPS improvement. Background draw calls are lower without removing scene detail. Maximum observed frames remain88.9–143.1ms. Texture memory~91.3MB includes the already-loaded texture even in fallback cases. This does not measure action or physical input latency, release binary performance, or user hardware.

## Shen support choreography · 2026-10-01 18:28 UTC

Shen Qing now has four project-original right-facing support key poses, normalized through Blender cards. Fixed foot(224,470), four512px cells and default156px stage cell preserve relative character size. Actual engine compositing verifies clean edges; an inspection viewer exaggerated saturated alpha1–2/255 fringe pixels, which were not opaque defects. The original selected source was not chroma-keyed or repainted. Other companion identities are not substituted with Shen's art.

The presentation extracts only identity-tagged accepted support logs. Direct healing and companion healing now have separate impact beats: self-healing0.25s, direct hit0.32s, support0.49s, support healing0.56s, incoming hit0.88s. Actual HP targets remain cumulative and clamped. Support-caused victory starts kneeling after the support contact, not before. Cover labels show the actual prevented amount and remain absent at zero. Exploration toasts are cleared on entering battle while persistent save errors remain visible.

Motion file: Hero-Shen-support.mp4;162frames;5.400seconds;1280×800;H.264;1,289,792bytes. SHA256:61f4b9e4c1a879ec9d2917b956f43d69d8815ca926a335c53fc2e56f90f8ce41. Fixed30FPS Movie Maker recording took11seconds,12including startup on cloudllvmpipe. This is a prepared source0.0.14 simulation, not release0.0.13 or a real-time benchmark. It uses ordinary64HP training encounters: two accepted attacks to trigger the every-second-attack assist/healing, then flee, switch formation outside combat and start the cover example. No enemyHP rewrite or fabricated combat result. Screenshots142–145 were rerendered by the same final code. AudioDummy, no listening claim; key poses are not full continuous skeletal animation.

## Village water material · 2026-10-01 19:09 UTC

The pond and ferry channel now sample one original painted daylight water material, aspect-preserved inside the existing geometry. Shore blending retains underlying earth detail. Existing ripple animation, pier walkability, dock geometry and islet traversal are retained. Captures148–151 show actual engine views;149 is the same runtime with the water material disabled, not a separate older executable. Piers, skiff and other regions still use their previous art.

Native ABBA diagnostic: stationary village at(1020,643),1280×800 world view,1180×812native window, Godot4.6.3 editor/OpenGLCompatibility/Mesa25.0.7/llvmpipeLLVM19.1.7. Water off/on/on/off:21.86/22.58/22.05/11.41FPS,945draw calls throughout. Each sample is4seconds; final off sample is noisy, so this is not evidence of a stable FPS improvement. Texture memory~74.1MB includes the already loaded painting in both settings. No Movie Maker, user-hardware or input-latency claim. Raw results:water_performance_results.json.
