# 03 技术方案

## 1. 选型：基于 FlClash 二次开发

| 候选 | 结论 |
|---|---|
| **[FlClash](https://github.com/chen08209/FlClash)** | ✅ 采用。Flutter + mihomo（Clash.Meta）内核，GPL-3.0；约 5.4 万星，维护非常活跃（2026-10-03 刚发布 v0.8.99）；mihomo 完整支持我们用的 VLESS Reality（vision）与 Hysteria2；同一套代码以后能出 Windows / macOS / Linux 版 |
| Clash Meta for Android | 纯安卓原生，只能出安卓版 |
| v2rayNG | 纯安卓原生；配置格式与我们的 Clash 订阅不匹配 |
| 从零开发 | 工作量大，VPN 稳定性要重新踩坑，不划算 |

PPanel 上游（perfect-panel）没有开源的官方客户端（2026-10 核实），所以对接面板的部分要自己写。

## 2. FlClash 现状（2026-10-04 核实）

| 项目 | 值 |
|---|---|
| 语言 / 框架 | Dart（Flutter 3.47.x，正式构建固定 3.47.4） |
| 内核 | Go 写的 mihomo，位于子模块 `core/Clash.Meta`（`git@github.com:chen08209/Clash.Meta.git`，分支 `FlClash`），胶水代码在 `core/*.go` |
| 其他原生库 | Rust（`plugins/rust_api`），构建时需要 rustup |
| 构建 | `flutter pub get` → `dart setup.dart android [--arch arm64]`，产物在 `dist/`。Go 内核与 Rust 库由 `plugins/setup/hook/build.dart` 在 `flutter build` 时自动编译 |
| 工具链版本 | Flutter 3.47.4、Go 1.26.4、JDK 17、Android compileSdk / targetSdk 37、minSdk 24、NDK 28.2.13676358、Rust stable |
| 包名 | `com.follow.clash`（debug 构建加 `.dev` 后缀） |
| 签名 | `android/app/keystore.jks`，加上 `android/local.properties` 里的 `storePassword`、`keyAlias`、`keyPassword` |
| 依赖的 Google 服务 | `com.google.gms.google-services`、`firebase-crashlytics`、`firebase-analytics`（**我们要移除**） |
| 状态管理 | Riverpod；本地数据库用 drift；有代码生成（freezed、build_runner） |
| 目录 | `lib/{application.dart, bootstrap.dart, main.dart, state.dart, common, core, database, enum, features, l10n, manager, models, pages, plugins, providers, views, widgets}` |
| 给 AI 的说明 | 仓库自带 `AGENTS.md` 与 `.agents/*.md`（项目说明、命令、规则、架构）。**修改 FlClash 原有代码时遵守这些规则** |

FlClash 的几条硬规则，Fork 之后仍然有效（摘自它的 AGENTS.md）：

- 修改模型、provider、数据库结构后要运行代码生成，**不要手改生成的文件**；
- 测试用 `flutter test`，不要用 `dart test`；
- Android VPN 服务的启停意图由 `ServiceState` 统一管理，UI 和 provider 只能请求状态切换，不能另起一套状态；
- 圆角统一用 `lib/common/shape.dart` 里的 `AppShape` / `AppRadius`（超椭圆），有测试强制检查；
- 遵守 `lint_options.yaml`：单引号、尾随逗号、不用 `print()` 等；
- FlClash 的提交钩子会拒绝 AI 署名（`Co-authored-by`）的提交。

## 3. 代码组织

> 2026-10-05 起：业务逻辑放 `lib/lightboat/logic/` 等共用位置，界面分 `mobile/`（安卓）和 `desktop/`（Windows）两套，各自设计。实际结构与规则见 [windows/W2 §3](windows/W2-architecture.md)。下面的目录树是最初的规划，已过时。

原则：**轻舟的代码尽量放在独立目录，对 FlClash 原有文件只做最小、可追踪的改动**，这样每次合并上游时冲突最少。

```
lib/
  lightboat/                  # 轻舟新增，全部放这里
    api/                      # 面板 HTTP 客户端：域名容灾、UA、错误码映射
    auth/                     # 登录、token 加密存储、登录失效处理
    captcha/                  # 滑块验证码组件
    subscription/             # 拉取订阅、写入 FlClash 配置、定时更新、userinfo 解析
    account/                  # 套餐信息、公告、续费跳转
    update/                   # 检查更新（latest.json）
    bootstrap/                # 远程面板地址列表（签名校验）
    pages/                    # 登录页、首页、我的页、设置页
    theme/                    # 轻舟配色、字体
    l10n/                     # 新增文案（接入 FlClash 的 arb 体系）
  ...（FlClash 原有目录，尽量不动）
docs/lightboat/
  upstream-patches.md         # 对 FlClash 原有文件的每一处改动：文件、原因、合并上游时要注意什么
```

### 必须改动的 FlClash 原有部分

| 改动 | 位置（大致） | 说明 |
|---|---|---|
| 包名、App 名、图标、启动页 | `android/app/build.gradle.kts`、`android/app/src/main/res/`、`AndroidManifest.xml`、`assets/` | 品牌化 |
| 移除 Firebase | `android/app/build.gradle.kts` 的插件与依赖、`google-services.json` 相关、Dart 侧的初始化与上报调用 | 隐私承诺；Google 服务在国内不可用 |
| 入口路由 | `lib/application.dart` 等 | 未登录进登录页，已登录进轻舟首页；FlClash 原有页面只从开发者模式进入 |
| 配置来源 | 配置文件（profile）管理相关的 provider | 由轻舟模块以编程方式创建 / 更新唯一的配置文件，并设为当前配置；隐藏手动添加入口 |
| 订阅请求的 UA | 下载配置文件的 HTTP 调用 | 必须带 `Lightboat-Android/<版本> (Clash.Meta)`，见 [02 §5](02-panel-integration.md) |
| 主题 | 主题相关代码 | 使用轻舟配色，关闭 Material You 动态取色（保证品牌色一致） |
| 更新检查 | FlClash 自带的 GitHub 更新检查 | 改成读轻舟官网的 `latest.json`（国内访问不了 GitHub） |

每一处改动都记进 `docs/lightboat/upstream-patches.md`。

## 4. 关键流程

### 4.1 登录与订阅同步

```
登录页 ──POST /v1/auth/login──▶ JWT（加密保存）
   └─ 110001 → 滑块 → 带 captcha_ticket 重试
JWT ──GET /v1/public/user/subscribe──▶ 选出有效订阅（status==1，或者唯一一份）
   └─ 保存订阅 token（加密）＋ 套餐快照（名称、到期、流量）
订阅 token ──GET https://<订阅域名>/api/subscribe?token=…（UA 含 Clash）──▶ YAML
   ├─ 写入 / 更新 FlClash 的唯一配置文件「轻舟」，设为当前配置
   ├─ 解析 subscription-userinfo → 更新流量与到期（JWT 失效时的兜底）
   └─ 默认把「🚀 Proxy」分组选成「🌏 Auto」
定时任务（每 6 小时，以及启动、回到前台超过 1 小时）：重复后两步
```

### 4.2 连接

沿用 FlClash 的 VpnService 启停逻辑，只换按钮和状态展示。首页按钮的状态：未连接 / 连接中 / 已连接 / 出错（附原因与「重试」）。第一次连接会弹出系统 VPN 授权；用户拒绝时，说明原因并引导再次授权。

### 4.3 登录失效

见 [02 §4](02-panel-integration.md)：JWT 失效**不影响连接**；订阅 token 失效（404 或空内容）时，用 JWT 重新拉订阅列表；两者都失效才回到登录页，并且保留「断开连接」的能力。

## 5. 域名容灾（抗封锁）

面板网站被封锁时可以换域名，但已安装的 App 如果只认一个域名，就会全部失效。所以从第一版起就要设计好：

1. **内置地址列表**：编译时写入一组面板地址，目前只有 `https://ssr.cnbetx.com`，以后增加备用域名。启动时用 `GET /v1/common/heartbeat` 按顺序探测，记住第一个可用的地址；
2. **远程地址列表**（P1）：从几个**和面板域名无关**的地址拉取一个 JSON（比如对象存储的公开桶、另一个域名下的静态文件）。格式示例：

   ```json
   {"version": 3, "panels": ["https://ssr.cnbetx.com", "https://备用域名"], "updated_at": 1791100000,
    "sig": "Ed25519 签名（base64）"}
   ```

   **必须校验签名**（公钥内置在 App 里），防止被劫持的地址把用户导到钓鱼面板；
3. 订阅域名以 `site/config` 返回的 `subscribe_domain` 为准；拉不到站点配置时，用上次缓存的值；
4. 节点地址在订阅配置里，由面板下发，App 不需要管。

## 6. 存储

| 数据 | 存放位置 |
|---|---|
| JWT、订阅 token | `flutter_secure_storage` 之类由 Android Keystore 支持的加密存储 |
| 订阅 YAML | FlClash 的配置文件目录（App 私有目录） |
| 套餐快照、公告已读、当前面板地址 | 普通偏好设置或 FlClash 的 drift 数据库 |
| 日志 | App 私有目录，滚动保留；导出前打码 |

## 7. 与上游 FlClash 保持同步

- Fork 后保留 upstream 远端：`git remote add upstream https://github.com/chen08209/FlClash.git`；
- 每月看一次上游的 release；需要新内核或修复时，在单独分支合并上游的 tag，解决冲突（主要看 `upstream-patches.md` 里列的文件），真机回归后再合入主分支；
- 不追每一个上游版本，但不要落后太多（内核安全修复很重要）；
- 子模块 `core/Clash.Meta` 跟随上游的提交，**不要自己改内核**。

## 8. 桌面版（Windows）

2026-10-04 决定：Windows 与安卓共用本仓库、同一套代码，分别构建（GitHub Actions 云端构建 Windows）。方案见 [windows/W2](windows/W2-architecture.md)。macOS / Linux 以后再说；iOS 不在计划内。
