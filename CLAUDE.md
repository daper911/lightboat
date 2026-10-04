# CLAUDE.md — 轻舟安卓客户端（Lightboat Android）

给 AI 编码助手的项目说明。每次开始工作前先读本文件；细节在 `docs/lightboat/`。

## 0. 沟通

- **始终用中文回复运营方**（包括解释、计划、总结）。代码、注释、提交信息用英文。
- 运营方不是安卓开发者：涉及他要动手的步骤（GitHub 网页操作、手机设置、安装 APK），要写清楚点哪里、填什么。
- 小而明确的改动直接做；涉及产品取舍（隐藏或删除功能、改包名、改面板）先讨论再做。

## 1. 项目是什么

为「轻舟」VPN 服务开发的安卓 App：用轻舟账号登录，一键连接。基于 **FlClash**（Flutter + mihomo 内核，GPL-3.0）二次开发，保留内核与 VPN 能力，换成轻舟品牌的极简界面，并对接轻舟面板。

- 需求：`docs/lightboat/01-product-requirements.md`
- 面板接口（已在线上核实）：`docs/lightboat/02-panel-integration.md`
- 技术方案：`docs/lightboat/03-architecture.md`
- 开发环境：`docs/lightboat/04-dev-environment.md`
- 构建与发布：`docs/lightboat/05-build-and-release.md`
- 测试：`docs/lightboat/06-testing.md`
- 里程碑：`docs/lightboat/07-milestones.md`
- 品牌与界面：`docs/lightboat/08-brand-and-ui.md`
- 轻舟项目现状：`docs/lightboat/09-project-context.md`

## 2. 当前状态与下一步

- 2026-10-04：只有文档，代码仓库还没建。
- 2026-10-04：**M0 完成**。私有仓库 `daper911/lightboat-android`（导入方式，不是 Fork），`upstream` 指向 FlClash；Docker 环境已验证，原版 FlClash arm64 包构建成功。容器内命令用 `env/run.sh <命令>`。
- 2026-10-04：**M1 原型代码完成**（待真机验证）：包名 `com.lightboat.app`（运营方确认），App 名「轻舟」、印章图标，去掉 Firebase；`lib/lightboat/` 实现登录（含滑块）、自动拉订阅、一键连接、线路选择、我的页；对 FlClash 的改动见 `docs/lightboat/upstream-patches.md`。
- 下一步：运营方建测试账号并真机验证 M1（06「账号」「连接」用例）；之后进入 M2（品牌细节、隐藏高级界面的入口打磨）与 M3（导出日志、检查更新、公告）。
- 完成一个里程碑，就更新本节。

## 3. 硬性约束

1. **只做 Android**。iOS 不做；桌面端代码保留不动（第二期再做）。
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
8. 包名在正式发布后**不能再改**；定下来之前用 debug 包名，不要自己拍板。

## 4. 关键事实速查

| 项目 | 值 |
|---|---|
| 面板 API | `https://ssr.cnbetx.com`，统一响应 `{code, msg, data}`，业务错误也是 HTTP 200；鉴权头 `Authorization: <JWT>`（不加 Bearer） |
| 登录 | `POST /v1/auth/login {email, password, captcha_ticket?}` → `data.token`（JWT，7 天） |
| 我的订阅 | `GET /v1/public/user/subscribe` → `data.list[]`（`token`、`status`、`expire_time` 毫秒、`traffic`/`upload`/`download` 字节、`subscribe.name`） |
| 订阅配置 | `https://sub.cnbetx.com/api/subscribe?token=<订阅token>`，**UA 必须含 `clash`**（App 用 `Lightboat-Android/<版本> (Clash.Meta)`），否则返回 base64；响应头 `subscription-userinfo`（expire 单位是秒） |
| 线路 | 把 `🚀 Proxy` 分组默认选成 `🌏 Auto`（url-test） |
| 滑块验证码 | 面板返回 `110001` 时：`GET /v1/common/captcha/slide` → 拖动 → `POST /v1/common/captcha/slide/verify {id, x, y}` → `ticket` → 带 `captcha_ticket` 重试。每张图只能提交一次，误差 5 像素，最少 0.4 秒 |
| 登录失效 | 40002–40005：只清 JWT，**不断开连接**；订阅 token 仍然可用 |
| 限流 | HTTP 429 + `{"code":401}`；不要激进重试 |
| 品牌色 | 主色 `#006C6C`（深色模式 `#65BCB7`），背景 `#FAF6EE` / `#08131A`，朱砂 `#C5372F`（Logo 与警示） |
| 工具链 | Flutter 3.47.4、Go 1.26.4、JDK 17、compileSdk 37、NDK 28.2.13676358、Rust stable |

## 5. 开发与测试环境

- 构建只在 Docker 容器里进行（`env/Dockerfile`）。宿主机上跑 docker 要加 `sudo`。
- 常用命令（容器内）：`flutter pub get`、`dart run build_runner build --delete-conflicting-outputs`、`flutter analyze`、`flutter test`、`dart setup.dart android --arch arm64`（产物在 `dist/`）。
- **没有 KVM，跑不了模拟器**。功能验证靠运营方的真机：构建好的 APK 由运营方在 VS Code 文件树里右键下载，再传到手机安装。告诉他文件在哪、怎么装、要测什么。
- 排查问题靠 App 的「导出日志」，或者运营方电脑上的 `adb logcat`。
- 测试账号在轻舟面板上单独创建（`probe-android-*@example.com`），不要用真实用户的账号。

## 6. 工作方式

- 每个里程碑结束时，给运营方一份中文小结：做了什么、APK 在哪、要他在手机上测哪几项（引用 06 的用例）、有什么需要他决定。
- 改动 FlClash 原有文件前，先读相关的 `.agents/architecture.md` 段落，确认生命周期的归属，再做最小改动。
- 合并上游 FlClash 时：单独开分支，按 `upstream-patches.md` 逐条检查，真机回归后再合入主分支。
- 文档与代码一起更新：接口变化改 02，范围变化改 01，新的约定写进本文件。
