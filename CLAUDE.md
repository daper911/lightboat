# CLAUDE.md — 轻舟客户端（Lightboat：Android + Windows）

给 AI 编码助手的项目说明。每次开始工作前先读本文件；细节在 `docs/lightboat/`。

## 0. 沟通

- **始终用中文回复运营方**（包括解释、计划、总结）。代码、注释、提交信息用英文。
- 运营方不是安卓 / Windows 开发者：涉及他要动手的步骤（GitHub 网页操作、手机设置、安装 APK、下载并安装 Windows 安装包），要写清楚点哪里、填什么。
- 小而明确的改动直接做；涉及产品取舍（隐藏或删除功能、改包名、改面板）先讨论再做。

## 1. 项目是什么

为「轻舟」VPN 服务开发的客户端：用轻舟账号登录，一键连接。基于 **FlClash**（Flutter + mihomo 内核，GPL-3.0）二次开发，保留内核与 VPN / 代理能力，换成轻舟品牌的极简界面，并对接轻舟面板。**同一套代码分别构建 Android 和 Windows**：轻舟的业务代码（`lib/lightboat/`）两个平台共用，只有界面外壳和少量平台功能分开。

- 需求：`docs/lightboat/01-product-requirements.md`
- 面板接口（已在线上核实）：`docs/lightboat/02-panel-integration.md`
- 技术方案：`docs/lightboat/03-architecture.md`
- 开发环境：`docs/lightboat/04-dev-environment.md`
- 构建与发布：`docs/lightboat/05-build-and-release.md`
- 测试：`docs/lightboat/06-testing.md`
- 里程碑：`docs/lightboat/07-milestones.md`
- 品牌与界面：`docs/lightboat/08-brand-and-ui.md`
- 轻舟项目现状：`docs/lightboat/09-project-context.md`
- **功能对照表**（每个功能归属哪个平台、各平台进度）：`docs/lightboat/feature-matrix.md`
- **Windows**：`docs/lightboat/windows/`（需求 W1、架构 W2、宽屏界面 W3、构建 W4、测试 W5、里程碑 W6）

## 2. 当前状态与下一步

- 2026-10-04：只有文档，代码仓库还没建。
- 2026-10-04：**M0 完成**。仓库 `daper911/lightboat-android`（导入方式，不是 Fork；当天下午变为公开），`upstream` 指向 FlClash；Docker 环境已验证，原版 FlClash arm64 包构建成功。容器内命令用 `env/run.sh <命令>`。
- 2026-10-04：**M1 原型代码完成**（待真机验证）：包名 `com.lightboat.app`（运营方确认），App 名「轻舟」、印章图标，去掉 Firebase；`lib/lightboat/` 实现登录（含滑块）、自动拉订阅、一键连接、线路选择、我的页；对 FlClash 的改动见 `docs/lightboat/upstream-patches.md`。
- 2026-10-04：**M2 代码完成**（待真机验证）：删除扫码导入（连同 Google ML Kit）；品牌启动页、通知栏 / 快捷开关小舟图标、标题衬线字体（`LightboatSerif`，只含「轻舟已过万重山」）；首次连接前的 VPN 授权说明；FlClash 原版界面只能从「我的 → 关于」连点 7 次进入；滑块验证码有组件测试覆盖（`test/lightboat/login_test.dart`）。
- 2026-10-04：运营方真机测过 0.2.0，工作正常。随后完成（0.3.0，待真机验证）：首页代理模式（智能分流 / 全局，不提供直连）、网速与本次用量、出口地区、连接时测一次延迟、连接失败与重试；「我的 → 分应用代理」；App 内原生注册；App 内购买 / 续费与付款（USDT 显示二维码，支付宝 / 微信跳浏览器收银台）。接口见 02 §2.6。
- 2026-10-04：GitHub 覆盖率检查修复（`30ff1b2a`：补轻舟界面测试并登记覆盖率标准）。
- 2026-10-04：**整合为安卓 + Windows 共用仓库**：仓库改名 `daper911/lightboat`，本机目录 `projects/lightboat`，Docker 镜像 `lightboat-env`；加入 Windows 规划（`docs/lightboat/windows/`）和云端构建流程 `.github/workflows/lightboat-windows.yml`（草稿，未跑过）。仓库保持公开（Windows 云端构建免费）。
- （2026-10-04 的安卓计划中，检查更新、导出日志、公告已在 0.4.0 完成；后台保活引导、自动连接暂缓，运营方 2026-10-05 把安卓专项定为界面细节打磨，见下文。）
- 2026-10-04：**W0 云端构建跑通**（`lightboat-windows` 首次运行即通过，run 37213624273，约 14 分钟）。W0 包仍用 FlClash 原版的 AppId、安装目录、数据目录（W1 才改），运营方的电脑上若有正版 FlClash 会冲突。运营方实测：全新 AWS Windows Server（香港）上登录报「网络连接失败」，原因是系统里没有 ISRG Root X2，已内置根证书修复（`53c22cfb`），修复后在该机器上登录、连接、打开 google.com 都正常；运营方自己在国内的电脑上 hysteria2 能测速、Reality 超时，但浏览器和 Telegram 上不了网，原因待查（怀疑是线路被墙，或 `🔍 Google` 等按应用分流的分组没有跟着首页的线路切换）。W2 §2 已写好待确认项的代码推断，其余项**等运营方实测**（W-I1、W-I5、W-A1、W-C1、W-C2、W-C6、W-C8，另加 W-I3、W-C9、W-A5）后回填。
- 2026-10-05：查明运营方电脑「测速通、上网不通」的原因：**「全局」模式实际全部直连**（mihomo 自动生成的 `GLOBAL` 默认 `DIRECT`），不是被墙；对比了小火箭与 Clash 两种订阅格式，节点参数完全一致。运营方决定：Windows 实测暂停，**先全面优化两个平台共用的功能，再全面优化安卓**，每项做之前先讨论。
- 共用优化（**0.4.0，待真机验证**；两个平台都生效，没有平台分支）：全局模式跟随线路（`GLOBAL` 固定为 `🚀 Proxy`）；线路列表隐藏直连；网络错误细分；「我的 → 导出日志」（打码，启动即收集 info 级日志）；规则集内置（`assets/lightboat/rules/`，首次连接不用下载 5.3 MB；`tool/lightboat/bundle_rules.py` 重新打包）；检查更新（R2 上的 `cdn.cnbetx.com/lightboat/latest.json`，`tool/lightboat/publish_r2.py` 发布，第一版用浏览器下载）；「我的 → 公告」与 popup 公告弹一次；套餐 3 天内到期 / 过期 / 流量用尽时启动弹「套餐提醒」（每天一次，运营方选 App 内弹窗，不做系统通知）。
- 安卓界面细节打磨（**0.4.1，待真机验证**，运营方 2026-10-05 选定的四项）：「我的」页分成套餐 / 连接 / 帮助 / 关于轻舟四组；通知标题显示「轻舟 · 当前节点」；对话框与底部提示统一品牌外观（`withLightboatBrand`、`lbToast`），「刷新套餐和线路」有结果提示，退出登录按钮写明操作；360dp 小屏 + 1.3 倍字体自动检查后修了一处溢出。系统通知设置里的类别名早已是「轻舟连接服务」。
- 2026-10-05：运营方在三星 A15 上装 0.4.1 失败，查明是**手机下载时文件损坏**（大小对、内容错，签名校验不过），重新下载后正常；R2 上加了校验页 `cdn.cnbetx.com/lightboat/check.html`，经验写在 05 §4。
- 2026-10-05：运营方决定**分流改成白名单**（国内名单直连、其余代理，名单用 MetaCubeX 的 `.mrs`），**当天已在主项目上线并验证**（02 §10）；轻舟只依赖 `🚀 Proxy`、`🌏 Auto` 两个分组名，不用发版。内置规则已在 `windows` 分支重新打包成白名单的 4 个 `.mrs`（2026-10-05），随下一版发布。
- 2026-10-05（主项目那边）：节点从国内连接时间歇丢包，根因未定（主项目 `docs/roadmap/node-stability.md`）；HK1 的 TCP 改成 AnyTLS（轻舟内核支持），新增 JP1 东京节点。**在国内网络下测出「连不上」不一定是客户端问题。**
- 2026-10-05：运营方定下 **Windows 方向**：用自己的桌面界面，不套手机界面；视觉走轻舟品牌风格（参考网站控制台，W3 方案 A）；首页、线路、购买、我的四页全部重新设计。同日完成**拆逻辑**：连接、购买、付款、登录流程从安卓页面拆到 `lib/lightboat/logic/`，目录改成 `logic/`、`widgets/`、`mobile/`（以后加 `desktop/`），安卓界面和行为不变（W2 §3）。
- **安卓下一步：深色模式逐页检查**（要运营方在手机上切到深色模式截图）；之后按运营方反馈继续打磨，或回到后台保活引导、自动连接。
- 2026-10-05：**W1–W3 代码完成（`windows` 分支，待运营方实测）**。W1：安装包 / 进程 / 图标 / 数据目录换成轻舟（AppId `E45C…`、发布者 `QINZHOU NETWORK CO.LLC`，运营方确认），卸载与升级时关闭指向 7890 的系统代理、删除开机自启，UA 带平台名；W2：`lib/lightboat/desktop/` 桌面界面（侧边栏 + 首页 / 线路 / 购买 / 我的，宽屏登录注册，付款对话框），轻舟托盘（`LbTray`），关闭缩到托盘时第一次说明，窗口 1080×720、最小 880×600；W3：「我的 → Windows 设置」、端口占用提示。对 FlClash 的改动见 `upstream-patches.md` 的 Windows 节。**运营方要求：Windows 全部功能做完、实测通过后再合并进 `main` 推送**；`windows` 分支每次推送都会云端构建（run 37366818343 是 W1 的第一次构建，通过；W1–W3 完整版是 run 37413614765，通过）。R2 上 FlClash 身份的 Windows 0.4.1 包，等轻舟版测过后直接替换（运营方确认没有别人装过）。运营方用国内网络的 Windows 电脑测试。
- **Windows 下一步：运营方实测 `windows` 分支的安装包**（W5：W-I、W-A、W-C、W-W、W-S、W-P），按反馈修改；通过后合并进 `main`、发版并替换 R2 上的 Windows 包。
- 完成一个里程碑，就更新本节。

## 3. 硬性约束

1. **只做 Android 和 Windows**。iOS、macOS、Linux 不做（FlClash 的这些平台代码保留不动）。**轻舟的业务逻辑只写一份**（`lib/lightboat/` 里 `mobile/`、`desktop/` 以外的部分，流程放 `logic/`），页面里不写判断、计时、重试和接口调用；**界面两套**：安卓在 `mobile/`、Windows 在 `desktop/`，互不引用，共用的小组件放 `widgets/`。只在确实需要时按平台分支（`system.isDesktop` / `Platform.isWindows` / `Platform.isAndroid`），并在 `docs/lightboat/windows/W2-architecture.md` §3 的分支点表里登记。新功能先在功能对照表登记归类。改共用代码时两个平台都要考虑。
2. **不改 mihomo 内核**（子模块 `core/Clash.Meta`），跟随上游。
3. **轻舟代码放在 `lib/lightboat/`**；对 FlClash 原有文件的每一处改动都记进 `docs/lightboat/upstream-patches.md`（文件、改动、原因、合并上游时的注意点），方便以后合并上游。
4. **移除 Firebase**（Analytics、Crashlytics、google-services），不加任何统计、崩溃上报、广告 SDK。
5. **不修改轻舟面板**。面板在另一个仓库（`/home/ubuntu/projects/vpn`）。需要面板配合的事项写进 02 §9，提醒运营方回到主项目处理。
6. **密钥不进 git**：签名证书（`*.jks`）、`android/local.properties`、密码、远程地址列表的签名私钥。导出的日志要打码 token、密码和订阅地址。
7. **FlClash 自带的规则同样适用**（根目录 `AGENTS.md` 与 `.agents/*.md`），尤其是：
   - 改了模型、provider、数据库后要跑代码生成，不要手改生成的文件；
   - 测试用 `flutter test`；
   - Android VPN 服务的启停只经过 `ServiceState`；
   - 圆角统一用 `AppShape` / `AppRadius`；
   - 遵守 `lint_options.yaml`；
   - FlClash 的 commit-msg 钩子会拒绝 `Co-authored-by` 署名行，**在本仓库提交时不要加**。
8. 包名在正式发布后**不能再改**；定下来之前用 debug 包名，不要自己拍板。Windows 安装包的 AppId 同理（见 §4），首次对外发布后永不修改。
9. **Windows 版不能在这台 Linux 服务器上编译**，只能用 GitHub Actions（`lightboat-windows`）云端构建。改了 Windows 相关代码，先在本机跑 `flutter analyze` 和 `flutter test`，再推送触发构建；结果由运营方在自己的 Windows 电脑上测。运营方没测过的 Windows 功能，不要说「已验证」。

## 4. 关键事实速查

| 项目 | 值 |
|---|---|
| 面板 API | `https://ssr.cnbetx.com`，统一响应 `{code, msg, data}`，业务错误也是 HTTP 200；鉴权头 `Authorization: <JWT>`（不加 Bearer） |
| 登录 | `POST /v1/auth/login {email, password, captcha_ticket?}` → `data.token`（JWT，7 天） |
| 我的订阅 | `GET /v1/public/user/subscribe` → `data.list[]`（`token`、`status`、`expire_time` 毫秒、`traffic`/`upload`/`download` 字节、`subscribe.name`） |
| 订阅配置 | `https://sub.cnbetx.com/api/subscribe?token=<订阅token>`，**UA 必须含 `clash`**（App 用 `Lightboat-<平台>/<版本> (Clash.Meta)`，平台为 `Android` / `Windows`；**W1 之前代码里写死 `Android`，Windows 版也这样发**），否则返回 base64；响应头 `subscription-userinfo`（expire 单位是秒） |
| 线路 | 把 `🚀 Proxy` 分组默认选成 `🌏 Auto`（url-test） |
| 滑块验证码 | 面板返回 `110001` 时：`GET /v1/common/captcha/slide` → 拖动 → `POST /v1/common/captcha/slide/verify {id, x, y}` → `ticket` → 带 `captcha_ticket` 重试。每张图只能提交一次，误差 5 像素，最少 0.4 秒 |
| 登录失效 | 40002–40005：只清 JWT，**不断开连接**；订阅 token 仍然可用 |
| 限流 | HTTP 429 + `{"code":401}`；不要激进重试 |
| 内置根证书 | `lib/lightboat/trust.dart` 内置 ISRG Root X1 / X2，因为全新 Windows 可能没有面板证书的根证书。**面板或订阅域名换证书机构（不再是 Let's Encrypt）时，要先把新的根证书加进这个文件** |
| 品牌色 | 主色 `#006C6C`（深色模式 `#65BCB7`），背景 `#FAF6EE` / `#08131A`，朱砂 `#C5372F`（Logo 与警示） |
| 工具链 | Flutter 3.47.4、Go 1.26.4、JDK 17、compileSdk 37、NDK 28.2.13676358、Rust stable |
| Windows 安装包 AppId | `{E45C3C6D-2F4C-4941-94D7-12924C55563A}`，**首次对外发布后永不修改** |
| Windows 进程名 | `Lightboat.exe`、`LightboatCore.exe`、`LightboatHelperService`（W1 改名，运营方已确认） |
| Windows 构建 | GitHub Actions `lightboat-windows`：推送到 `main`（相关路径）、推送 `lb-v*` 标签或手动触发；产物在该次运行页面底部的 Artifacts |
| Windows 默认 | 系统代理；TUN 不在主界面；关闭窗口 = 缩到托盘；宽屏布局（侧边栏 + 内容区） |
| Windows 签名 | 暂不签名（SmartScreen、智能应用控制的影响见 windows/W4 §5） |

## 5. 开发与测试环境

- 构建只在 Docker 容器里进行（`env/Dockerfile`）。宿主机上跑 docker 要加 `sudo`。
- 常用命令（容器内）：`flutter pub get`、`dart run build_runner build --delete-conflicting-outputs`、`flutter analyze`、`flutter test`、`dart setup.dart android --arch arm64`（产物在 `dist/`）。
- **没有 KVM，跑不了模拟器**。功能验证靠运营方的真机：构建好的 APK 由运营方在 VS Code 文件树里右键下载，再传到手机安装。告诉他文件在哪、怎么装、要测什么。
- 排查问题靠 App 的「导出日志」，或者运营方电脑上的 `adb logcat`。
- 测试账号在轻舟面板上单独创建（`probe-android-*@example.com`、`probe-windows-*@example.com`），不要用真实用户的账号。
- **Windows**：本机只能做静态检查和单元测试（`env/run.sh flutter analyze`、`env/run.sh flutter test`）。构建：`git push` 后 GitHub Actions 自动运行 `lightboat-windows`，或在 Actions 页手动 Run workflow；查看结果见 `docs/lightboat/windows/W4-build-and-ci.md` §2。运营方下载 Artifacts 里的安装包，在 Windows 上安装测试（W5 写了每一步）。
- 每次 Windows 的改动都不能破坏安卓：里程碑结束时在本机构建一次安卓 debug 包确认能编译。

## 6. 工作方式

- 每个里程碑结束时，给运营方一份中文小结：做了什么、APK 在哪、要他在手机上测哪几项（引用 06 的用例）、有什么需要他决定。
- Windows 里程碑的小结还要包含：Actions 运行的链接、下载哪个文件（安装版 / 免安装版）、安装时会遇到的拦截提示和放行方法、本次要测的用例编号（W5）。
- 安卓和 Windows 两个 AI 对话同时开工时，用 git worktree 分开目录（例如 `git worktree add ../lightboat-win -b windows`），做完一个里程碑再合并回 `main`。
- 改动 FlClash 原有文件前，先读相关的 `.agents/architecture.md` 段落，确认生命周期的归属，再做最小改动。
- 合并上游 FlClash 时：单独开分支，按 `upstream-patches.md` 逐条检查，真机回归后再合入主分支。
- 文档与代码一起更新：接口变化改 02，范围变化改 01，新的约定写进本文件。
