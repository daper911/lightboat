# W2 Windows 技术方案

## 1. 选型：为什么是 FlClash，而且和安卓共用一套代码

2026-10-04 调研的开源 Windows 代理客户端（GitHub 数据，当天）：

| 项目 | 技术 | 内核 | 许可证 | 星标 | 结论 |
|---|---|---|---|---|---|
| **FlClash** | Flutter（Dart） | mihomo | GPL-3.0 | 5.4 万 | ✅ 采用 |
| Clash Verge Rev | Tauri（Rust + React） | mihomo | GPL-3.0 | 14.9 万 | 备选：Windows 上最成熟，但要另起一套代码 |
| Clash Party | Electron（TypeScript） | mihomo | GPL-3.0 | 2.7 万 | 安装包大、占内存多 |
| Clash Nyanpasu | Tauri | mihomo | GPL-3.0 | 1.3 万 | 与 Verge Rev 同源，规模小 |
| v2rayN | C# | Xray / sing-box | GPL-3.0 | 11.8 万 | 内核与订阅格式不同 |
| Hiddify / Karing | Flutter | sing-box | 非标准许可证 | 3.3 万 / 1.5 万 | 商用有许可证风险 |

选 FlClash 的理由：

1. **轻舟安卓版已经基于 FlClash**，`lib/lightboat/` 里的登录、注册、滑块、购买、付款、首页、线路都是纯 Dart，在 Windows 上直接可用；
2. FlClash 原生支持 Windows：官方 CI 构建 Windows x64 / ARM64，带 Inno Setup 中文安装程序、Rust 写的后台服务（TUN 用）、托盘、开机自启、系统代理；
3. **一份代码**：面板接口只对接一次；上游 FlClash 只合并一次；两个平台的内核、订阅 UA、分流规则完全一致，排查问题时没有平台差异；
4. 选 Clash Verge Rev 意味着用 React 重写全部轻舟业务，并长期维护两套代码。只有在 W0 验证中发现 FlClash 的 Windows 质量明显不行时才改道（W6 W0 的验收）。

## 2. FlClash Windows 端的现状（2026-10-04 在仓库里核实）

| 部分 | 实现 | 位置 |
|---|---|---|
| 窗口 | `window_manager`；自绘标题栏；记住大小和位置；最小尺寸 380×400 | `lib/common/window.dart`、`lib/manager/window_manager.dart` |
| 单实例 | Windows 启动器里检查已有窗口 | `windows/runner/win32_window.cpp` |
| 托盘 | `tray_manager` | `lib/manager/tray_manager.dart` |
| 系统代理 | `systemProxy` 设置，桌面端默认开启 | `lib/manager/proxy_manager.dart`、`lib/models/config.dart` |
| 开机自启 / 静默启动 / 启动后自动连接 / 关闭缩到托盘 | `autoLaunch`（默认关）/ `silentLaunch`（关）/ `autoRun`（关）/ `minimizeOnExit`（开） | `lib/models/config.dart`、`lib/common/launch.dart` |
| 内核 | 独立进程 `FlClashCore.exe`，通过命名管道 `\\.\pipe\FlClashCore_<随机>` 通信 | `lib/common/path.dart:62`、`lib/common/constant.dart:19` |
| 后台服务 | `FlClashHelperService`（Rust，`services/helper`），安装程序以管理员身份注册，用于 TUN 等需要特权的操作 | `services/helper`、`windows/packaging/exe/inno_setup.iss` |
| 安装包 | Inno Setup；`app_id`、名称、发布者、图标在 `make_config.yaml`；需要管理员；自带简体中文语言文件 | `windows/packaging/exe/` |
| 打包命令 | `dart setup.dart windows` → `dist/` 下的 `.exe` 安装程序和 `.zip` 免安装包（架构跟随构建机器） | `setup.dart` |
| 未签名提示 | FlClash 已内置「智能应用控制拦截了未签名的 FlClashCore.exe」等提示文案 | `lib/l10n/` |
| 判断桌面 | `system.isDesktop`（Windows / macOS / Linux） | `lib/common/system.dart:32` |

W0 要在真机上确认的行为。「代码推断」是 2026-10-04 读 FlClash 代码得出的；「实测」由运营方在 Windows 上测过后填写，没测过的一律写「待测」。

| 项目 | 代码推断 | 实测（用例） |
|---|---|---|
| 单实例 | 两层：启动器先找已有窗口并激活它（`windows/runner/main.cpp`），Dart 侧再加锁文件 `FlClash.lock`（`lib/common/lock.dart`）；应正常 | 待测（W-I3） |
| 异常退出后的系统代理 | `ProxyManager` 启动时 `fireImmediately` 用「未连接」状态调用一次 `stopProxy()`，所以**重新打开程序**就会关掉残留的系统代理；但在重新打开之前，整机上网会失败。注意这是无条件关闭，也会关掉别的代理软件设置的系统代理（W-C11） | 待测（W-C8） |
| 睡眠唤醒 | 没有专门处理（`suspendProvider` 指的是「指定 Wi-Fi 下暂停」，与睡眠无关）；内核进程和系统代理在睡眠期间保持不变 | 待测（W-C9） |
| 卸载清理 | `inno_setup.iss` 卸载时只注销后台服务、`taskkill /f` 结束进程：**不恢复系统代理**（强制结束不会走程序的清理），**不删除开机自启项**（`launch_at_startup` 写在 `HKCU\…\Run`）。预计 W-I5 不通过，W1 补卸载脚本 | 待测（W-I5） |
| 数据目录 | `getApplicationSupportDirectory()` = `%APPDATA%\<CompanyName>\<ProductName>`，取自 `windows/runner/Runner.rc`，目前是 `%APPDATA%\com.follow\clash`（**与正版 FlClash 相同**）。W1 改 `Runner.rc` 后路径会变；首次对外发布前改，不影响用户 | 待测 |
| 凭据存储 | `flutter_secure_storage` 的 Windows 实现：用系统 DPAPI 加密，文件存在上面的数据目录里 | 待测（W-A5） |
| 根证书 | 面板和订阅域名的证书链止于 ISRG Root X2（Let's Encrypt）。Windows 只在自己的系统组件需要时才下载缺少的根证书，Dart 却只读系统里已有的；全新的 Windows（例如云服务器）上没有 X2，App 登录就报「网络连接失败」。已修：`lib/lightboat/trust.dart` 在启动时内置 ISRG Root X1、X2（两个平台都加，不分支） | 2026-10-04 运营方在 AWS 全新 Windows Server 上复现（`certutil -store root` 里没有 ISRG，`Test-NetConnection` 通）；内置证书后（`53c22cfb`，run 37224312058）同一台机器登录、连接、打开 google.com 都正常 |

## 3. 代码组织：共用代码 + 两个外壳

```
lib/lightboat/
├─ api/            面板接口（两个平台共用，不改）
├─ auth/           凭据存储（共用；Windows 上 flutter_secure_storage 走系统加密）
├─ session.dart    登录状态、订阅同步（共用）
├─ config.dart     常量；userAgent 按平台生成（见 §5）
├─ theme.dart      品牌色（共用；桌面端补充侧边栏、标题栏的颜色角色）
├─ strings.dart    文案（共用；桌面专属文案也放这里）
├─ pages/          页面内容（共用的部分抽成「不带 Scaffold 的内容组件」）
├─ shell/          ← 新增
│   ├─ mobile_shell.dart    手机外壳：现有的首页 + 推入式页面，行为不变
│   └─ desktop_shell.dart   桌面外壳：侧边栏 + 内容区（W3）
└─ desktop/        ← 新增，只在 Windows 上用
    ├─ tray.dart            托盘菜单与图标状态（基于 FlClash 的 tray_manager）
    ├─ window.dart          标题栏样式、关闭缩到托盘的提示、窗口默认尺寸
    └─ settings.dart        「Windows 设置」：开机自启、静默启动、自动连接
```

规则：

1. **外壳选择只有一处**：`LbRoot` 在已登录时按 `system.isDesktop` 返回 `DesktopShell` 或 `MobileShell`。以后若要让安卓平板也用宽屏布局，再改成按窗口宽度判断；
2. **页面内容只写一份**：现在的页面（如 `home.dart` 里的套餐卡片、连接按钮、线路卡片）拆成内容组件，手机外壳和桌面外壳各自摆放；
3. **平台分支要集中、可查**：只在下面列出的地方按平台分支，新增分支点时更新本表。

| 分支点 | Android | Windows |
|---|---|---|
| 外壳 | `MobileShell` | `DesktopShell` |
| 「我的」页 | 分应用代理、保活引导 | Windows 设置（开机自启等） |
| 首次连接前的说明 | VPN 授权说明 | 不显示（系统代理不需要授权） |
| 托盘 / 标题栏 | 无 | `lib/lightboat/desktop/` |
| UA 平台名 | `Android` | `Windows` |

## 4. 关键流程

### 4.1 启动

1. FlClash 启动内核与窗口（单实例检查在最前面）；
2. `lightboatPrepare()` 照安卓的做法替用户应答首启对话框、设置品牌色与 UA，Windows 上额外设置：窗口默认尺寸（W3 §1）、托盘图标、关闭 GitHub 更新检查；
3. 恢复登录状态 → 已登录进入桌面外壳，未登录显示登录页（宽屏居中卡片，W3 §3）；
4. 如果开了「启动后自动连接」，登录状态恢复后自动连接。

### 4.2 连接与断开

- 连接：拉取 / 更新订阅 → 启动内核 → 设置系统代理（指向 `127.0.0.1:<混合端口>`）→ 托盘图标变为已连接；
- 断开：恢复系统代理 → 停止内核代理 → 托盘图标变灰；
- 退出（托盘菜单）：先断开，再退出进程；
- 异常退出：下次启动时检查系统代理，若仍指向本机端口而内核未运行，恢复为连接前的设置（W0 先测 FlClash 现有行为）。

### 4.3 后台服务与权限

- 安装程序以管理员身份运行，注册后台服务（W1 起改名为 `LightboatHelperService`）。第一版只用系统代理，**正常使用时不需要管理员权限**；服务是给以后的 TUN 准备的；
- 卸载时停止并删除服务、恢复系统代理、删除开机自启项（Inno Setup 卸载脚本）。

## 5. 必须改动的 FlClash 原有部分（Windows）

全部记进 `docs/lightboat/upstream-patches.md` 的「Windows」节。

| 位置 | 改动 | 里程碑 |
|---|---|---|
| `lib/lightboat/config.dart` | `userAgent` 改为 `Lightboat-${Platform.isWindows ? 'Windows' : 'Android'}/$version (Clash.Meta)`（轻舟自己的文件，不算上游补丁） | W1 |
| `lib/lightboat/root.dart` | 按平台选外壳（轻舟文件） | W2 |
| `windows/packaging/exe/make_config.yaml` | `app_id: E45C3C6D-2F4C-4941-94D7-12924C55563A`（**首次发布后永不修改**，否则用户升级会变成装两份）；`app_name`/`display_name: 轻舟`；`publisher: QINZHOU NETWORK CO.LLC`；`publisher_url: https://ssr.cnbetx.com`；`executable_name`/`output_base_file_name` 改为 Lightboat | W1 |
| `windows/packaging/exe/inno_setup.iss` | 结束进程、注销服务里的进程名同步改名；安装目录 `Lightboat` | W1 |
| `windows/CMakeLists.txt`（`BINARY_NAME`）、`windows/runner/main.cpp`（窗口标题）、`windows/runner/Runner.rc`（文件说明、公司名、版权） | 主程序名与资源信息改为轻舟 | W1 |
| `windows/runner/resources/app_icon.ico` | 换成轻舟印章图标（16–256 px 多尺寸） | W1 |
| `lib/common/path.dart`、`lib/common/constant.dart`、`setup.dart`、`services/helper`、`inno_setup.iss`、`lib/l10n`（拦截提示文案里的进程名） | 进程改名（运营方 2026-10-04 确认）：`FlClashCore` → `LightboatCore`、`FlClashHelperService` → `LightboatHelperService`、命名管道前缀 `FlClashCore_` → `LightboatCore_`；全仓库搜索 `FlClashCore`、`FlClashHelperService`、`FlClash.exe` 确认没有遗漏；安卓不受影响（这些只在桌面端使用） | W1 |
| `lib/manager/tray_manager.dart` | 托盘菜单换成轻舟的精简菜单（或由 `lib/lightboat/desktop/tray.dart` 接管，尽量少改上游文件） | W2 |
| `lib/manager/window_manager.dart`（标题栏） | 标题栏颜色、标题文字用轻舟品牌；能通过主题实现就不改文件 | W2 |
| `.github/workflows/build.yaml` | 去掉 Linux / macOS 的 debug 构建（整合时做） | 整合 |

改动 FlClash 文件前先读 `.agents/architecture.md` 对应段落，确认生命周期归属（例如系统代理的开关只经过 FlClash 现有的 manager，不要另起一套）。

## 6. 存储位置

| 内容 | 位置 |
|---|---|
| FlClash 配置、订阅文件 | `getApplicationSupportDirectory()`，W0 记下 Windows 上的实际路径（通常在 `%APPDATA%` 下） |
| 登录凭据 | `flutter_secure_storage`（系统加密） |
| 日志导出 | 用户的「下载」文件夹 |

## 7. 与上游 FlClash 同步

与安卓相同（安卓 03 §7）：单独开分支合并上游，按 `upstream-patches.md` 逐条检查；**Windows 和安卓各在真机上回归一遍**才能合入主分支。合并后 Windows 的构建由 Actions 自动跑。
