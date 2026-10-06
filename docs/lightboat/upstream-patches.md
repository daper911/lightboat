# 对 FlClash 原有文件的改动（upstream patches）

合并上游 FlClash 时逐条检查本表：上游改了同一处就手工合并，合并后真机回归。轻舟自己的代码全部在 `lib/lightboat/`、`test/lightboat/`、`docs/lightboat/`、`env/`，不在本表里。

基线：上游 `chen08209/FlClash` 的 `4b59eca8`（v0.8.99 之后，2026-10-04）。

## Dart

| 文件 | 改动 | 原因 | 合并上游时注意 |
|---|---|---|---|
| `lib/application.dart` | `MaterialApp.home` 的 `HomePage()` 换成 `LbRoot()`；`title` 用 `LbStrings.appName`；`theme` / `darkTheme` 末尾加 `.withLightboatBrand`（纸色背景、品牌色对话框与底部提示，`lib/lightboat/theme.dart`） | 轻舟的登录页 / 首页取代 FlClash 首页；最近任务里显示「轻舟」 | FlClash 的 `HomePage` 仍可从「我的 → 关于」连点 7 次后的「高级」进入 |
| `lib/bootstrap.dart` | `_initApp()` 开头加 `await lightboatPrepare(_container);` | 在 FlClash 弹出免责声明 / Crashlytics 提示之前替用户应答，关闭 GitHub 更新检查，设置品牌色与订阅 UA，恢复登录状态 | 上游若改动 `_initApp` 的启动顺序，确认这行仍在首个对话框之前 |
| `pubspec.yaml` | `version` 改为轻舟自己的版本号（`0.1.0+1` 起，规则见 05 §2） | 版本号与 UA 都取自这里 | 合并上游时保留我们的 `version` 行 |
| `lib/common/picker.dart`、`lib/providers/actions/profiles.dart`、`lib/views/profiles/add.dart`、`lib/pages/pages.dart`；删除 `lib/pages/scan.dart`、`test/pages/scan_test.dart`；`test/views/add_profile_view_test.dart` 改为断言没有扫码入口 | 删除「扫二维码导入配置」（`pickerConfigQRCode`、`addProfileFormQrCode`、`ScanPage`、添加配置页的扫码入口） | 扫码依赖的 Google ML Kit 自带 Google 数据上报组件（datatransport），与「不集成统计」冲突；轻舟界面也用不到（运营方 2026-10-04 决定删除） | 上游改动扫码相关代码时直接丢弃；`lib/common/link.dart` 的 `profileUrlFromQrCodes` 保留未动，现在只有测试在用 |
| `lib/providers/state/system.dart`、`lib/providers/state.dart` | `sharedState` 的 `currentProfileName` 改为 `ref.watch(lbNotificationTitleProvider)`（`state.dart` 加对应 import） | 安卓连接通知的标题显示「轻舟 · 当前节点」（自动选择时显示它选中的节点），`lib/lightboat/notification.dart` | 合并上游时若 `sharedState` 改名或拆分，把通知标题的取值换回这个 provider |
| `pubspec.yaml` | 删除 `mobile_scanner`、`image_picker`；`fonts:` 新增 `LightboatSerif`（`assets/fonts/LightboatSerif.ttf`，许可证 `LightboatSerif-OFL.txt`） | 同上；品牌标题字体（08 §4）：网站「轻舟宋」子集再裁到只含「轻舟已过万重山」，2.8 KB | |
| `pubspec.yaml` | 新增依赖 `qr`（纯 Dart） | App 内付款页画 USDT 收款二维码 | |
| `pubspec.yaml` | `assets:` 新增 `assets/lightboat/rules/` | 内置订阅用到的规则集，首次连接不用先下载（02 §5）；2026-10-05 起是白名单的 4 个 `.mrs`（gzip 后 0.58 MB，02 §10） | 合并上游时保留这一行 |
| `pubspec.yaml`、`pubspec.lock`，以及 `flutter pub get` 重新生成的 `linux/`、`macos/`、`windows/` 插件注册文件 | 新增依赖 `flutter_secure_storage` | JWT 与订阅 token 存进 Android Keystore 加密存储（01 §7） | 生成文件冲突时直接重新 `flutter pub get`；第二期做 Linux 桌面版时要装 `libsecret-1-dev` |

## Android

| 文件 | 改动 | 原因 | 合并上游时注意 |
|---|---|---|---|
| `android/app/build.gradle.kts` | `applicationId` 改为 `com.lightboat.app`（`namespace` 仍为 `com.follow.clash`）；移除 google-services、Crashlytics 插件、Firebase 依赖与符号上传任务 | 包名（运营方 2026-10-04 确认）；移除 Firebase（CLAUDE.md §3.4） | `namespace`、Kotlin 包名、`Components.PACKAGE_NAME` 都保持 `com.follow.clash`，只改 `applicationId`，这样 Kotlin 代码和 MethodChannel 名称与上游一致 |
| `android/settings.gradle.kts` | 删除 `com.google.gms.google-services`、`com.google.firebase.crashlytics` 插件声明 | 同上 | |
| `android/common/build.gradle.kts` | 删除 Firebase BOM、crashlytics-ndk、analytics 依赖 | 同上 | |
| `android/common/src/main/java/com/follow/clash/common/GlobalState.kt` | `setCrashlytics` 改为空操作，`didCrashOnPreviousExecution` 固定返回 `false` | 没有 Firebase；保留函数签名，调用方不用改 | 上游新增 Firebase 调用时同样处理 |
| `android/app/google-services.json` | 删除 | 同上 | |
| `android/common/src/main/res/values/strings.xml` | `app_name` 改为「轻舟」，通知渠道名改为「轻舟连接服务」 | 品牌 | |
| `android/app/src/main/res/drawable/ic_launcher_foreground.xml`、`values/ic_launcher_background.xml`、`mipmap-xxxhdpi/ic_launcher*.png` | 换成轻舟印章图标（朱砂底 `#C5372F`、白色舟形线条）；安卓 7.x 用的位图取自网站 `pwa-192x192.png`，旧的 `.webp` 位图删除 | 品牌（08 §2） | Android TV 图标（`mipmap-television-*`、`ic_launcher_foreground_tv.xml`）没有改 |
| `android/app/src/main/res/values*/styles.xml`（四个） | 启动窗口与 Flutter 底色改为宣纸色 `@color/lb_paper`；安卓 12+ 启动页：宣纸底 + 朱砂圆底白色小舟（`windowSplashScreenIconBackgroundColor`） | 品牌；避免启动时闪白 / 闪黑、整屏朱砂 | 颜色定义在轻舟新增的 `values/lightboat_colors.xml`、`values-night/lightboat_colors.xml` |
| `android/service/src/main/res/drawable/ic.xml`、`ic_service.xml` | 换成白色小舟线条 | 通知栏小图标、快捷开关图标（08 §2） | FlClash 的 `.agents/commands.md` 说它们来自 `glyph.svg`，我们不再跟随那个来源 |

## Windows

计划见 [windows/W2 §5](windows/W2-architecture.md)。进程改名（运营方 2026-10-04 确认）：主程序 `Lightboat.exe`、内核 `LightboatCore.exe`、后台服务 `LightboatHelperService`、命名管道前缀 `LightboatCore_`。安卓不受影响（内核与后台服务只在桌面端使用）。

| 文件 | 改动 | 原因 | 合并上游时注意 |
|---|---|---|---|
| `build_config.yaml`（仓库根目录） | `core_name` 改为 `LightboatCore`、`helper_name` 改为 `LightboatHelperService`，其余行不动 | 构建钩子（`plugins/setup/setup_hooks/lib/src/options.dart`）读这个文件，不用改钩子代码；后台服务编译时内嵌的内核文件名和 SHA256 也跟着变 | 上游改这个文件时保留这两行 |
| `lib/common/constant.dart` | `appName` 改为 `Lightboat`、`appHelperService` 改为 `LightboatHelperService`、Windows 命名管道前缀改为 `LightboatCore_` | 进程改名；`appName` 同时决定开机自启的注册表项名、托盘提示、日志 / 备份文件名、TUN 网卡名、锁文件名 | 三个值要和 `build_config.yaml`、`services/helper` 保持一致；`test/core/transport_test.dart`（管道前缀）、`test/state_run_globals_test.dart`（默认 UA 里的程序名）的期望值同步改了 |
| `lib/common/path.dart` | 内核路径 `LightboatCore.exe`；锁文件改为 `$appName.lock` | 同上 | |
| `services/helper/src/service/windows.rs`、`hub.rs`、`build.rs` | 服务名 `LightboatHelperService`；允许的管道前缀 `\\.\pipe\LightboatCore_`（及对应测试数据）；`CORE_NAME` 默认值 `LightboatCore.exe` | 后台服务只接受这个前缀的内核地址，必须和 Dart 一致 | Linux 的 socket 前缀与测试数据没有改 |
| `arb/intl_*.arb`（四种语言）及生成的 `lib/l10n/` | `helperCorruptTip`、`coreBlockedByPolicyTip`、`coreBlockedBySmartAppControlTip` 里的 `FlClashCore.exe` / `FlClash` 改为 `LightboatCore.exe` / 轻舟（英、日、俄文用 Lightboat） | Windows 用户会看到这些提示（内核被智能应用控制拦截时） | 上游改这几条文案时重新替换名字，再 `dart run intl_utils:generate`，**生成后对 `lib/l10n/` 运行 `dart format`**（FlClash 的 `build` 工作流检查全部代码格式，生成的文件不格式化会失败，2026-10-06 出过一次） |
| `windows/CMakeLists.txt` | `project(Lightboat)`、`BINARY_NAME "Lightboat"`；安装步骤里的内核 / 后台服务文件名 | 主程序名与进程改名 | |
| `windows/runner/main.cpp` | 窗口标题改为「轻舟」（用 `\u8F7B\u821F` 转义，因为 runner 不是按 UTF-8 编译的） | 品牌 | 单实例检查按程序路径匹配，与标题无关 |
| `windows/runner/Runner.rc` | 公司名 `QINZHOU NETWORK CO.LLC`、文件说明「轻舟」、产品名 / 内部名 `Lightboat`、原始文件名 `Lightboat.exe`、版权 | 任务管理器显示「文件说明」；**数据目录由公司名和产品名决定，变为 `%APPDATA%\QINZHOU NETWORK CO.LLC\Lightboat`**，不再和正版 FlClash 共用 `%APPDATA%\com.follow\clash` | 首次对外发布后不要再改公司名和产品名，否则用户的数据目录会变 |
| `windows/runner/resources/app_icon.ico` | 换成轻舟印章（16–256 px，由 `widgets/logo.dart` 同一份 SVG 渲染） | 品牌；安装程序图标也用它 | |
| `windows/packaging/exe/make_config.yaml` | `app_id` 改为 `E45C3C6D-2F4C-4941-94D7-12924C55563A`（**首次对外发布后永不修改**）；名称、显示名「轻舟」、发布者 `QINZHOU NETWORK CO.LLC`、网址、可执行文件名 | 安装包身份；安装目录随 `app_name` 变为 `C:\Program Files\Lightboat` | |
| `windows/packaging/exe/inno_setup.iss` | 结束进程、注销服务改用新名字；安装 / 升级前和卸载时，系统代理若指向 `127.0.0.1:7890` 就关掉（同时改 WinINet 的 `DefaultConnectionSettings` 标志位并通知系统）；卸载时删除开机自启（`Run`、`StartupApproved\Run`、启动文件夹里的快捷方式） | `taskkill /f` 不会走程序自己的清理，原来卸载后会「整机上不了网」（W-I5）；只关自己端口的代理，不动其他代理软件的设置 | 卸载程序以管理员身份运行，`HKCU` 是确认 UAC 的那个账户；标准用户输入管理员密码时清理的是管理员账户的设置 |
| `lib/common/app_ports.dart` | 新增全局钩子 `beforeHideToTray` | 关闭窗口缩到托盘之前，轻舟第一次弹出「轻舟仍在后台运行」的说明（`lib/lightboat/desktop/tray.dart`，由 `lightboatPrepare` 挂上）；用钩子是为了不让 FlClash 的状态层引用轻舟界面代码 | |
| `lib/providers/actions/system.dart` | `handleClose` 在桌面端缩到托盘前、且是用户点关闭时，调用 `beforeHideToTray` | 同上 | 上游改 `handleClose` 时保留这一行 |
| `lib/models/config.dart`（`WindowPropsExt.size`，手写扩展，不是生成代码） | 没有保存过窗口大小时默认 1080×720（原 680×580）；`test/models/config_test.dart` 的期望值同步改 | 桌面界面的默认尺寸（W3 §1） | |
| `lib/common/window.dart` | 最小窗口 880×600（原 380×400） | 侧边栏 + 内容区在更窄时会挤压（W3 §1） | |
| 托盘（不改上游文件） | `lightboatPrepare` 在桌面端把 `trayPort` 换成 `LbTray`（`lib/lightboat/desktop/tray.dart`）：小舟图标（未连接灰色、已连接江青色，`assets/lightboat/tray/`）、精简菜单（状态、连接 / 断开、模式、打开轻舟、退出） | FlClash 的托盘菜单有 TUN、系统代理开关、复制环境变量等，不适合轻舟用户（W3 §6） | 上游改 `TrayPort` 接口时同步改 `LbTray` |
| `pubspec.yaml` | `assets:` 新增 `assets/lightboat/tray/` | 托盘图标 | 合并上游时保留这一行 |
| `.github/workflows/lightboat-windows.yml` | 推送到 `windows` 分支也触发构建 | Windows 里程碑在 `windows` 分支上开发，每次推送都出测试包 | 合并回 `main` 后可以保留 |

## 构建

| 文件 | 改动 | 原因 |
|---|---|---|
| `.github/workflows/build.yaml` | `desktop` 任务的矩阵只留 `windows`，去掉 Linux、macOS | 轻舟只出安卓和 Windows；省掉每次推送两台无关的云主机构建。上游改动该矩阵时保留只有 windows 这一项 |
| `.github/workflows/lightboat-windows.yml`（新增） | 轻舟自己的 Windows 构建与发布流程 | 见 [windows/W4](windows/W4-build-and-ci.md)。上游升级 Flutter / Go 版本时同步这里的 `FLUTTER_VERSION`、`GO_VERSION` |
| `tool/check_coverage.dart` | `_groupFloors` 新增 `'lightboat': 86.0` | CI 要求每个代码组都登记覆盖率下限；轻舟代码 2026-10-04 实测 88.5% | 上游调整这张表时保留这一行 |
| `.gitignore` | `docs/` 改为 `docs/*` + `!docs/lightboat/`；新增 `*.jks`、`key.properties` | 提交轻舟文档；签名证书不进 git |
