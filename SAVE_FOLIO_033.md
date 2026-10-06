# 旅途手记 · 0.0.33 development checkpoint

## 2026-10-06 · 0.0.33 Web1「旅途手记」已上线

存档、读档、当前／备份详情与确认页采用统一书册外观，保存结果及读取失败在当前页直接显示；快捷数字、键盘焦点和较窄窗口的确认文字已修正。三份手记、格式 16、备份规则、各来源自动保存、队伍与资源保持，文件转存默认关闭。

固定运行源码为 GitHub `82073338`（本地受测 `50b3100`），1,747 份受测文件、384 份运行输入。完整源码回归、原生矩阵、源码 21,584 项、Linux 精确包 21,589 项及三组补充 11,499／1,738／449 项完成独立验收；Windows 构建与九个历史／新包边界进程另行通过。原导出时间戳检查失败与限定单包例外完整保留，各组覆盖不相加。新增文档和 JSON 是测试后记录，不冒称与原受测整仓相同。

15:10:26 UTC 原子切换，15:18:18 主审确认 36／36 项 HTTPS 与 14 份完整资源核验。旧 Web32 服务目录和服务器 ZIP 在恢复副本及两次零读取者核验后退役，历史、正式恢复包、测试记录与存档保留。实际浏览器游戏、声音及 IndexedDB 刷新持久性仍未验收；没有新增 GitHub 安装包或发行条目。详见[上线记录](tests/web_deployment_033.json)、[旅途手记说明](SAVE_FOLIO_033.md)与[精确包验收](tests/save_folio_package_validation.json)。下方按原时点保留历史记录。


### 上线前完整验收记录

以下候选状态记于部署前，后续上线以上方记录为准。

## 2026-10-06 · 当前验收状态

本轮改动覆盖原有手动存档、读档、当前／备份详情与确认页的书册外观，并使保存结果与读档失败在当前页面可见。原生焦点不会自行触发操作；Tab 进入选项后由按钮处理 Enter／空格一次。无焦点的首选快捷方式保留；标题回调有代次保护，书册回调在退出中拒绝执行。

三份手记、自动档只读入口、格式 16、槽路径、LocalSaveSlots、HeroState、剧情、队伍和资源不变。探索关闭仍自动保存；标题取消、配件只读浏览、默认关闭的转存返回浏览仍保持各自抑制规则。读档成功而随后自动保存失败时保留已加载分支及警告；原规则允许有效主档先轮换到备份再发生主档写入失败，本轮没有增加备份日志保证。

`50b3100`（远端 `82073338`）完整回归和源码演练均已独立通过：183 个保留脚本＋1 次导入、93 项 Python、53 项模拟 DOM、11,499／1,738／449／1,380 项补充，以及 21,584 项源码演练。逻辑几何单独覆盖 18 份样本；12 张原生图／492 项仍绑定实际 `3d5aa59` 拍摄及未变的 384 份运行输入。原生矩阵为物理 1280×800／960×600、逻辑 1280×800，直接逻辑 1179×737 的几何证据另列。预置状态、脚本输入、固定帧率与 Dummy 音频不作人工浏览器试玩。

旧完整回归的 120 秒超时失败和首次几何诊断失败均保留。超时调整仅作用于一个原有剧情检查；新完整回归已通过该案 4,104 项／两种结果，未削弱断言或改变游戏。原 `save_folio_timeout_recovery.json` 描述当时仍待完整回归的历史状态，新完成结果单独记录。

导出程序成功，外层严格元数据 guard 保持失败。完整导出区间的事前启动观察只发现 `.recovery_mode_lock` 创建／写入后关闭／删除这一组变更；目录身份与权限、原空子目录、源码和精确产物均另行核验，但未获得责任 PID。例外只允许原封不动的这一包进入隔离 PCK 验证，不作普遍放宽。

独立 Windows 源码 21,584、实际 PCK 21,589、九个历史／新包进程和九个隔离检查已由主审核验；四份外置探针仅改预期摘要，Web25 仍限旧 13 脚本加当前依赖。Linux 缺少历史包输入，未执行对应历史进程；Windows 结果不转记为 Linux 通过。Linux 同一实际 PCK 的 21,589 项与三组补充 11,499／1,738／449 项已全部通过并独立验收；线上保持 0.0.32 Web1。浏览器游戏、音频及 IndexedDB 未验收，转存默认关闭。本记录不宣称新桌面发行包、GitHub 安装包／发行条目、商业 1.0 或原 1,882 文件历史恢复。

记录：[完整回归](tests/save_folio_full_regression.json)、[超时恢复](tests/save_folio_timeout_closure.json)、[原生画面](tests/save_folio_native_review.json)、[精确包状态](tests/save_folio_package_validation.json)、[单包导出例外](tests/save_folio_export_adjudication.json)、[Windows 验证](tests/save_folio_windows33_validation.json)。

下方各阶段记录按其原时点保留；新的完整回归结果不改写旧失败回执。

新增说明与 JSON 是测试后的记录闭环，不改变受测 pin，也不声称其后文档整仓重新执行了完整回归。

The existing three manual-save slots, autosave load entry, current/backup details and explicit overwrite/load confirmations now use the original cloth-and-paper folio family. Slot metadata stays adjacent to its actual action. Existing save-result and failed-load text is also shown inside the active folio, while the original toast and autosave-warning behavior remain.

The earlier native32 baseline reproduced all three hidden-feedback cases in137 checks: successful manual save, real write failure and failed title load. The new focused suite passed449 checks across ten cases with real production I/O, actual key/pointer dispatch, isolated prepared faults, state/file evidence and terminal integrity. See `tests/save_folio_baseline.json` and `tests/save_folio_checkpoint.json`. At that first checkpoint, native visual/full-regression/package acceptance was still pending. Current native acceptance and full-run recovery are recorded below. Live remains0.0.32 Web1.

Native focus does not automatically select or invoke an action. Tab enters the choices; a focused native button handles Enter/Space once, while the existing unfocused first-choice shortcut remains. Title choices gain generation guards, and local folio callbacks reject quit-pending, including Back. These narrow input protections are explicitly recorded rather than described as unchanged behavior.

LocalSaveSlots, HeroState, schema16, slot paths/count, resources and save/backup behavior are unchanged. Normal exploration dismissal still autosaves; title cancellation, fitting read-only browsing and dormant transfer-return browsing retain their distinct suppression. Successful load followed by failed autosave keeps the loaded branch and warning. A valid primary may already have rotated into backup before a later primary-write failure; this scope adds no backup journal. Transfer remains default-off.

Current remaining gates: complete retained regression plus focused supplements, exact source/Web PCK and independent Windows boundaries. The final twelve native frames, direct compact geometry and sampled contrast/focus have passed on runtimef490c445 with their own recorded bindings. No new illustration or gameplay content is added.

## Native candidate and shortcut refinement

The first frozen candidate `cfbb902` (remote `c02af30e`) subsequently passed12 actual native frames and492 checks, with independent pixel review at1280×800 and960×600. Its raw Label control rectangles are oversized and are not strict containment proof; the actual glyphs, complete consequences, feedback and focus were separately inspected. Actual cinnabar unreadable-state samples measured7.11:1 /5.64:1.

A following presentation-only refinement moves each existing shortcut number inside its own button. Captions, option order and callbacks are unchanged. The fresh focused rerun passed449 checks on runtime9d29b995; its own subsequent12-frame native run passed492 checks with independent pixel/contrast review, while full/package gates remain pending. The earlier pixel acceptance is not transferred to those later bytes.

## Direct compact confirmation correction

The5180220 native review covers physical1280×800 and960×600 with logical1280×800. A separate true logical1179×737 diagnostic found overwrite prose204px high in a199.325px viewport. Its first attempt also contained an unsupported focus-metric API call; all failed evidence is retained and is not called a pass.

Confirmation prose now uses the available space above the unchanged action row. A corrected fresh diagnostic passed1,380 checks across18 page/size samples: content204 fits230px at1280 and217.088px at1179, without hidden continuation. The unchanged449-check save/input/failure suite also passed on runtimef490c445. Protected official import generated the geometry test UID with no original-file changes.

These are exact logical layout measurements. Label character envelopes are not raster ink bounds; earlier PNG acceptance stays bound to its earlier runtime. At this correction freeze, fresh native pixels/full regression/package/platform gates were pending. The subsequent3d5aa59 native run passed12 frames/492 checks with independent pixel review (SHA256f42bbb3f8c9ea597f6097d67b75c4a8657e602f2ad99d3bb9cf24edc99cb095d); full/package/platform gates remain pending. See `tests/save_folio_compact_geometry.json`.

## One retained scene timeout corrected

The complete3d5aa59 regression stopped after54 successful canonical processes: `heting_consignee_earned_party_test.gd` exceeded its default120-second wall limit. This remains a failed full run, with raw evidence retained. The same unchanged test previously finished in106.084seconds. Its first current outcome matched the prior one; the second had made recorded progress. No specific slowdown cause or memory failure is asserted.

A fresh isolated one-case diagnostic, with only a240-second allowance and300-second outer bound, completed4,104 checks/two outcomes/six companion-method records in121.607seconds. All1,746 originals, runtime and helpers remained unchanged. The source runner now assigns240seconds only to this invocation; test bodies, all184 engine argument vectors and every other limit remain unchanged. A complete fresh full run is still required before source/PCK admission. The existing native acceptance remains bound to unchanged runtimef490c445 and its actual3d5aa59 capture. See `tests/save_folio_timeout_recovery.json`.
