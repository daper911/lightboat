# 对 FlClash 原有文件的改动（upstream patches）

合并上游 FlClash 时逐条检查本表：上游改了同一处就手工合并，合并后真机回归。轻舟自己的代码全部在 `lib/lightboat/`、`test/lightboat/`、`docs/lightboat/`、`env/`，不在本表里。

基线：上游 `chen08209/FlClash` 的 `4b59eca8`（v0.8.99 之后，2026-10-04）。

## Dart

| 文件 | 改动 | 原因 | 合并上游时注意 |
|---|---|---|---|
| `lib/application.dart` | `MaterialApp.home` 的 `HomePage()` 换成 `LbRoot()`；`title` 用 `LbStrings.appName` | 轻舟的登录页 / 首页取代 FlClash 首页；最近任务里显示「轻舟」 | FlClash 的 `HomePage` 仍可从「我的 → 关于」连点 7 次后的「高级」进入 |
| `lib/bootstrap.dart` | `_initApp()` 开头加 `await lightboatPrepare(_container);` | 在 FlClash 弹出免责声明 / Crashlytics 提示之前替用户应答，关闭 GitHub 更新检查，设置品牌色与订阅 UA，恢复登录状态 | 上游若改动 `_initApp` 的启动顺序，确认这行仍在首个对话框之前 |
| `pubspec.yaml` | `version` 改为轻舟自己的版本号（`0.1.0+1` 起，规则见 05 §2） | 版本号与 UA 都取自这里 | 合并上游时保留我们的 `version` 行 |
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

## 构建

| 文件 | 改动 | 原因 |
|---|---|---|
| `.gitignore` | `docs/` 改为 `docs/*` + `!docs/lightboat/`；新增 `*.jks`、`key.properties` | 提交轻舟文档；签名证书不进 git |
