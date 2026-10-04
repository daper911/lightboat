# 轻舟 Windows 版 · 文档索引

轻舟 Windows 版和安卓版是**同一个仓库、同一套代码**（FlClash 二次开发），分别构建。安卓文档（`docs/lightboat/01–09`）里与平台无关的部分对 Windows 同样适用，尤其是：

- 面板接口契约：[02-panel-integration.md](../02-panel-integration.md)（Windows 不另起接口）
- 品牌色、字体、Logo：[08-brand-and-ui.md](../08-brand-and-ui.md)
- 轻舟项目现状：[09-project-context.md](../09-project-context.md)

本目录只写 Windows 特有的内容：

| 文档 | 内容 |
|---|---|
| [W1-requirements.md](W1-requirements.md) | 产品需求：共用功能、Windows 专属功能、优先级、非功能要求、不做的事、待决定事项 |
| [W2-architecture.md](W2-architecture.md) | 选型理由、代码组织（共用代码 + 手机外壳 + 桌面外壳）、FlClash 桌面端机制、必须改的地方 |
| [W3-desktop-ui.md](W3-desktop-ui.md) | 宽屏界面：窗口、侧边栏、各页面、托盘菜单、文案 |
| [W4-build-and-ci.md](W4-build-and-ci.md) | GitHub Actions 云端构建、安装包、版本号、不签名的后果与应对、发布 |
| [W5-testing.md](W5-testing.md) | 运营方怎么下载、安装、测试；测试环境；回归清单 |
| [W6-milestones.md](W6-milestones.md) | 里程碑 W0–W4、工作量、验收标准 |

## 2026-10-04 定下的方向

底座 FlClash（与安卓共用）· GitHub Actions 云端构建 · 运营方在 Windows 上测试 · 暂不签名 · 传统宽屏桌面布局 · 默认系统代理。
