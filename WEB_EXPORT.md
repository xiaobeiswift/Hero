# 浏览器试玩与静态部署

当前是电脑键盘浏览器预览的开发阶段。原生桌面版仍可从README中的完整发行链接下载；Web导出成功不等于浏览器或服务器验收完成，以对应BUILD-REPORT与后续浏览器记录为准。

## 玩家需要知道

- 使用支持WebAssembly和WebGL2的新版桌面浏览器；点「启程」，再点游戏画面后操作。WASD/方向键移动，E交互，数字键选择
- 用游戏左下「存卷」「读卷」或「小憩」按钮；不要依赖浏览器可能占用的F键
- 进度和设置保存在当前浏览器、当前网站；清除网站数据、更换浏览器或设备不会自动带走进度。没有账号或服务器存档同步
- 刷新、关闭页签前先在小憩中保存或保存并返回首页。桌面版的窗口关闭恢复流程不能保证保护浏览器关闭/刷新
- 若顶部提示没有持久存储，当前页内的进度可能在刷新后丢失。一次保存返回成功也不是跨刷新持久化证明，必须以实际重开验收为准
- 当前仍需键盘，不把手机能够打开页面视为支持触控游玩；音频通常需要一次点击/按键后才启动

## 可复现构建

使用固定官方Godot4.6.3引擎及同版本导出模板。官方模板下载地址：
https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/Godot_v4.6.3-stable_export_templates.tpz

完整TPZ约1.256GB。先测量临时目录空间与内存，再下载；不要占满项目卷。`tools/install_web_templates.py <TPZ路径>`校验固定官方SHA512，再只安装两份单线程Web模板，约19.7MB。脚本不会下载、修改账号或安装服务器软件。

提交稳定源码后执行：

```sh
python3 tools/export_web.py --label Hero-Web-preview-唯一标签
```

构建要求768MiB起始工作区空间，运行期间保留512MiB，并限制导出大小与时间；这不改变桌面导出的1100MiB门槛。输出为`builds/<标签>/site/`及经过成员字节验证的ZIP，保留源码、引擎和模板摘要。单线程、无扩展、无PWA或第三方请求，不需要共享内存隔离头。

## 部署交接

服务器只需提供静态文件，不运行Godot、不需要游戏后端。解压ZIP后将`Hero-Web`内全部文件作为一个完整版本放在新目录中，保留许可证；不要只上传HTML，也不要改动引擎、PCK及辅助JS文件名。

- 首先只读检查目标域名、HTTPS、现有站点根目录、Web服务器和路径权限。所有路径/域名由部署者明确选择；文档不包含真实服务器地址、用户或密钥
- `.wasm`使用`application/wasm`；`.pck`使用`application/octet-stream`；JS/HTML使用正常类型。建议服务器对大资源启用已有的gzip/Brotli支持
- 为整个版本使用独立目录，先验收后切换入口；保留上一版以便回退。HTML及版本入口应重新验证缓存，避免旧HTML配上新引擎/PCK。没有配置离线Service Worker
- HTTPS是正式部署目标。不要覆盖无关站点配置、修改防火墙或账户权限；先确认已有配置和实际授权范围
- 浏览器验收至少包括首次启程、移动/E、手记保存、视野/乐声偏好、刷新与重开恢复、返回首页/继续、窗口缩放、南庭演武；记录实际浏览器版本，不能把原生测试代替浏览器验证

参考：[Godot4.6 Web导出](https://docs.godotengine.org/en/4.6/tutorials/export/exporting_for_web.html)、[浏览器存储接口](https://docs.godotengine.org/en/4.6/classes/class_os.html#class-os-method-is-userfs-persistent)。当前未在此流程中连接、修改或部署任何用户服务器。
