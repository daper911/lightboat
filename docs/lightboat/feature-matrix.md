# 功能对照表（Android / Windows）

每个功能先在这里归类，再动手（流程见 [windows/W2 §3](windows/W2-architecture.md)）。共用功能的逻辑只写一份（`lib/lightboat/` 里 `mobile/`、`desktop/` 以外的部分），两边界面各做一次。

状态：✅ 已有　🟡 共用逻辑已有，缺这个平台的界面　⏳ 计划中　— 不适用

最后核对：2026-10-05（代码 0.4.1）。Windows 目前显示的是手机界面（W0），所以共用功能在 Windows 上都标 🟡，W2 里程碑做完桌面界面后改成 ✅。

## 共用功能

| 功能 | 逻辑位置 | Android | Windows | 说明 |
|---|---|---|---|---|
| 登录（含滑块验证码）、登录状态恢复、退出 | `session.dart`、`logic/account.dart`、`widgets/captcha.dart` | ✅ | 🟡 | 登录失效只清登录，不断连接 |
| 注册（邮箱验证码、邀请码） | 同上 | ✅ | 🟡 | |
| 自动拉订阅、定时更新（启动、每 6 小时、回到前台超过 1 小时） | `session.dart` | ✅ | ✅ | 没有界面 |
| 一键连接 / 断开、启动失败与重试 | `logic/connection.dart` | ✅ | 🟡 | 安卓多一步 VPN 授权说明 |
| 代理模式：智能分流 / 全局 | `logic/connection.dart` | ✅ | 🟡 | 全局跟随线路 |
| 线路选择、测延迟、连接后自动测一次、出口地区 | `logic/connection.dart` | ✅ | 🟡 | 线路列表隐藏直连 |
| 网速、本次用量 | FlClash 的 provider | ✅ | 🟡 | |
| 套餐卡片：到期、流量、提示 | `logic/plan.dart` | ✅ | 🟡 | |
| 多个套餐时切换 | `session.dart` | ✅ | 🟡 | |
| 购买 / 续费、付款（USDT 二维码，支付宝 / 微信跳浏览器） | `logic/purchase.dart` | ✅ | 🟡 | |
| 启动时套餐提醒（每天一次） | `logic/plan.dart`、`widgets/prompts.dart` | ✅ | ✅ | 弹窗共用 |
| 公告列表、popup 公告弹一次 | `logic/account.dart`、`widgets/prompts.dart` | ✅ | 🟡 | popup 弹窗已共用；列表要桌面界面 |
| 检查更新（`latest.json`，浏览器下载） | `update.dart` | ✅ | ✅ | 按平台读各自的条目 |
| 导出日志（打码） | `diagnostics.dart` | ✅ | 🟡 | Windows 的保存位置待实测 |
| 内置规则集（首次连接不用下载） | `rules.dart` | ✅ | ✅ | 白名单上线后要重新打包（02 §10.4） |
| 内置根证书 | `trust.dart` | ✅ | ✅ | |
| 隐藏的 FlClash 原版界面（关于连点 7 次） | `mobile/me.dart` | ✅ | 🟡 | |

## 只有 Android

| 功能 | Android | 说明 |
|---|---|---|
| 首次连接前的 VPN 授权说明 | ✅ | Windows 用系统代理，不需要授权；**现在 Windows 上误显示，W1 隐藏** |
| 分应用代理 | ✅ | **现在 Windows 的「我的」里误显示，W1 隐藏** |
| 通知栏显示「轻舟 · 当前节点」、快捷开关 | ✅ | |
| 后台保活引导 | ⏳ | 暂缓 |
| 开机自动连接 | ⏳ | 暂缓 |

## 只有 Windows

优先级见 [windows/W1 §5](windows/W1-requirements.md)。

| 功能 | Windows | 里程碑 |
|---|---|---|
| 轻舟品牌的安装包、进程名、图标、数据目录 | ⏳ | W1 |
| 卸载时恢复系统代理、删除开机自启项 | ⏳ | W1 |
| UA 带平台名 `Lightboat-Windows` | ⏳ | W1（现在 Windows 也发 `Lightboat-Android`） |
| 桌面界面：标题栏、侧边栏、四个页面重新设计 | ⏳ | W2 |
| 托盘：状态图标、菜单；关闭缩到托盘 | ⏳ | W2（FlClash 底层已有） |
| 开机自启、静默启动、启动后自动连接 | ⏳ | W3（FlClash 底层已有，缺界面） |
| 异常退出后恢复系统代理、端口占用提示、系统代理被改提示 | ⏳ | W3 |
| 睡眠唤醒、切换网络后恢复 | ⏳ | W3（先实测） |
