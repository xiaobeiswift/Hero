# 开篇原生图形路线验收

运行时源码：`7328e1a21f4934537a050e03eb903342aca5e20b`。这是源代码引擎会话，不是新的独立发行包。196份运行时文件在开始和结束后逐项SHA256一致，清单见 `native_opening_runtime.sha256`；实际驱动摘要、路线、数值及结果见 `native_opening_route.json`。

从无存档的标题页开始，脚本用普通移动输入走到东北苇岸采药，返回药铺交药并邀请沈青，再走到旧渡口交战，回村交付账页，选择“守望”和听潮阁，最后按F5/F9保存和续写。路线没有修改人物坐标、任务阶段、攻击、气血或奖励，也没有关闭碰撞或跳过战斗演出。最终角色为3级、124气血、110铜钱，沈青仍同行；蒲横以正常96气血开始交锋。

最终运行通过全部阶段，步行约3673世界单位，使用5次正常战斗行动。记录耗时约32秒，包含脚本快速确认对白；这不是实际玩家的章节时长或帧率指标。观察了运行中的原生交锋窗口；截图216–218分别来自采药后、交锋开始和第一章完成，均1280×800。

环境为Godot4.6.3、X11、OpenGL Compatibility与llvmpipe。音频驱动为Dummy。这里验证脚本驱动的原生图形流程，不宣称人工连续通关、音频听感、Windows/macOS原生验证或独立包验收。

## 在Linux图形环境复现

必须使用全新隔离数据目录；数据目录名称须以 `-route-data` 结尾。驱动拒绝普通玩家配置目录和已有自动存档，不会为重跑删除旧档。它会更新本仓库的216–218截图与JSON测试记录。

```sh
HERO_ROUTE_ROOT="$(mktemp -d /tmp/hero-opening.XXXXXX)"
XDG_DATA_HOME="$HERO_ROUTE_ROOT/profile-route-data" \
XDG_CONFIG_HOME="$HERO_ROUTE_ROOT/config" \
XDG_CACHE_HOME="$HERO_ROUTE_ROOT/cache" \
HERO_QA_SOURCE_COMMIT="$(git rev-parse HEAD)" \
godot --path . --audio-driver Dummy --script tests/play_opening_route.gd
```

该脚本不加入默认无头测试入口。源码语法导入及此次完整原生路线已验；现有运行时仍保持其已通过的完整无头回归结果。
