# 轻舟客户端（Lightboat：Android + Windows）

为「轻舟」VPN 服务开发的自有客户端，**同一套代码分别构建 Android 和 Windows**：用户用轻舟账号登录，点一个按钮就能连上，不需要知道订阅链接、客户端、协议这些概念。

这里是轻舟客户端的全部文档（2026-10-04 编写），在代码仓库 `daper911/lightboat` 中位于 `docs/lightboat/`。01–09 以安卓为主，其中与平台无关的部分（面板接口、品牌、项目现状）两个平台共用；Windows 特有的内容在 [windows/](windows/README.md)。

## 文档

| 文档 | 读者 | 内容 |
|---|---|---|
| [CLAUDE.md](../../CLAUDE.md) | AI 编码助手 | 项目上下文、硬性约束、关键事实、工作方式（AI 每次打开项目时自动读取） |
| [01-product-requirements.md](01-product-requirements.md) | 所有人 | 产品需求：目标、范围、核心流程、功能清单与优先级、非功能要求 |
| [02-panel-integration.md](02-panel-integration.md) | 开发 | 与轻舟面板的对接契约：接口、订阅、错误码、限流、滑块验证码（均已在线上核实） |
| [03-architecture.md](03-architecture.md) | 开发 | 技术方案：基于 FlClash 二次开发、代码组织、需要改动的地方、域名容灾、上游同步 |
| [04-dev-environment.md](04-dev-environment.md) | 开发 / 运营方 | **从零开始的操作步骤**：建仓库、搭 Docker 构建环境、第一次构建、装到手机 |
| [05-build-and-release.md](05-build-and-release.md) | 开发 / 运营方 | 签名证书、版本号、打包、分发、应用内更新、GPL 开源义务 |
| [06-testing.md](06-testing.md) | 开发 / 测试 | 真机测试方法、机型矩阵、测试用例清单 |
| [07-milestones.md](07-milestones.md) | 所有人 | 里程碑、工作量、每一步的验收标准 |
| [08-brand-and-ui.md](08-brand-and-ui.md) | 开发 / 设计 | 品牌：名称、Logo、配色（十六进制）、字体、界面草图、文案 |
| [09-project-context.md](09-project-context.md) | 所有人 | 轻舟项目现状：面板、节点、域名、支付、安全，与 App 相关的部分 |
| [feature-matrix.md](feature-matrix.md) | 所有人 | **功能对照表**：每个功能是两个平台共用、只安卓还是只 Windows，各平台做到哪一步 |
| [windows/](windows/README.md) | 所有人 | **Windows 版**：需求、架构、宽屏界面、云端构建、测试、里程碑（W1–W6） |
| [env/](../../env/)（仓库根目录） | 开发 | 构建环境的 Dockerfile 与 VS Code 开发容器配置（草稿，第一次搭建时验证） |

## 一句话方案

Fork 开源客户端 **[FlClash](https://github.com/chen08209/FlClash)**（Flutter + mihomo 内核，GPL-3.0），保留它的内核与 VPN 能力，把界面换成轻舟品牌的三个页面（登录 / 一键连接 / 我的），加上与轻舟面板的对接。

## 怎么开始（运营方视角）

1. 读 [01-product-requirements.md](01-product-requirements.md) 末尾的「待决定事项」，把能定的先定下来（App 名称、包名、图标）。
2. 在 GitHub 上 Fork FlClash，按 [04-dev-environment.md](04-dev-environment.md) 第 1 节操作（约 5 分钟）。
3. 在 VS Code 里打开新的项目文件夹，让 AI 助手按 [07-milestones.md](07-milestones.md) 从 M0（搭环境）开始做。
4. 准备一台安卓真机（最好再借两台不同品牌的），用来安装测试包。

## 和轻舟主项目的关系

- 主项目（面板、网站、部署）：`/home/ubuntu/projects/vpn`，仓库 `git@github.com:daper911/mvpn.git`。
- 本项目只调用面板的公开接口，**不修改面板代码**。确需面板配合的改动（比如延长登录有效期、托管 APK），记录在 [02-panel-integration.md](02-panel-integration.md) 的「需要面板配合」一节，回到主项目里改。
