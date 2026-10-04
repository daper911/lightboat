# W4 Windows 构建、安装包与发布

## 1. 为什么用 GitHub Actions

Flutter 的 Windows 程序只能在 Windows 上编译（需要 Visual Studio 的 C++ 工具链），这台 Linux 开发服务器编译不了。GitHub Actions 提供免费的 Windows 云主机（公开仓库不限时长），FlClash 自己的发布流程就是在上面构建的。

| 环节 | 在哪里 |
|---|---|
| 写代码、静态检查、单元测试 | 本机（`env/run.sh flutter analyze`、`env/run.sh flutter test`） |
| 编译 Windows 安装包 | GitHub Actions（`windows-2022` 云主机） |
| 安装、测试 | 运营方的 Windows 电脑 |

## 2. 构建流程 `lightboat-windows`

文件：`.github/workflows/lightboat-windows.yml`。2026-10-04 首次运行（W0）未作修改即通过：[run 37213624273](https://github.com/daper911/lightboat/actions/runs/37213624273)，用时约 14 分钟（其中编译打包 6 分钟），产物 zip 约 104 MB。

| 触发 | 用途 |
|---|---|
| 推送到 `main`，且改动了 `lib/`、`windows/`、`core/`、`plugins/`、`services/`、`pubspec.*`、`assets/` 或流程文件本身 | 日常：AI 推送后自动出包 |
| 手动（Actions 页 → lightboat-windows → Run workflow） | 想重打一个包时 |
| 推送标签 `lb-v*` | 正式版：同时创建 GitHub Release 并附上安装包（满足 GPL 开源义务） |

步骤：检出（含子模块）→ 安装 Go、Rust 缓存、Flutter（版本与 FlClash CI 一致）→ `flutter pub get` → `flutter analyze` → `dart setup.dart windows`（生成 `dist/*.exe` 和 `dist/*.zip`）→ 计算 SHA256 → 上传为 Artifact（保留 14 天）。

一次构建约 15 分钟（首次实测 14 分钟）。同一分支连续推送时，旧的构建会被自动取消，只保留最新一次。

**AI 怎么看结果**：本机没有 `gh` 命令时，用公开接口查询：

```bash
curl -s "https://api.github.com/repos/daper911/lightboat/actions/workflows/lightboat-windows.yml/runs?per_page=3" \
  | python3 -c "import json,sys;[print(r['status'],r['conclusion'],r['html_url']) for r in json.load(sys.stdin)['workflow_runs']]"
```

失败时用 `…/actions/runs/<id>/jobs` 接口看是哪一步失败（不需要登录）；**日志下载接口即使是公开仓库也要登录**（未登录返回 403），所以要看具体报错，需请运营方在运行页面里展开失败步骤截图，或在本机装 `gh` 并登录（运营方同意后）。修好再推。需要更方便时可以在本机装 `gh` 并登录（运营方同意后）。

## 3. 安装包

| 产物 | 文件名 | 说明 |
|---|---|---|
| 安装版 | `Lightboat-<版本>-windows-amd64-setup.exe` | Inno Setup 中文安装程序；需要管理员确认一次（注册后台服务）；装到 `C:\Program Files\Lightboat`；建开始菜单和桌面快捷方式 |
| 免安装版 | `Lightboat-<版本>-windows-amd64.zip` | 解压即用，适合不想安装的用户；没有后台服务（不能用 TUN），系统代理模式正常 |
| 校验 | `SHA256SUMS` | |

文件名格式在 W1 品牌化时通过 `make_config.yaml` 与 `setup.dart` 的输出命名统一调整，以实际产物为准并回写本表。

安装包的固定信息（W1 写进 `make_config.yaml`）：

| 字段 | 值 |
|---|---|
| AppId | `{E45C3C6D-2F4C-4941-94D7-12924C55563A}` —— **首次对外发布后永不修改** |
| 名称 | 轻舟 |
| 发布者 | QINZHOU NETWORK CO.LLC |
| 网址 | https://ssr.cnbetx.com |
| 图标 | 轻舟印章（多尺寸 `.ico`） |

## 4. 版本号

- 与安卓**共用** `pubspec.yaml` 的 `version`（如 `0.4.0+4`）。一套代码，一个版本号；某次只改了 Windows，也照样递增；
- Windows 安装程序显示 `0.4.0`；`+` 后面的数字只对安卓有意义；
- 正式版标签仍是 `lb-v<版本>`，一个标签同时对应安卓 APK 和 Windows 安装包。

## 5. 不签名：会遇到什么、怎么应对

运营方决定第一版暂不签名。未签名的 Windows 程序会遇到三种拦截，严重程度不同：

| 拦截 | 现象 | 应对 |
|---|---|---|
| **SmartScreen**（所有 Windows 10 / 11） | 运行安装程序时蓝色窗口「Windows 已保护你的电脑」 | 点「更多信息」→「仍要运行」。写进网站下载页和教程，配截图 |
| **Defender / 其他杀毒软件误报** | 代理类软件常被报为「风险程序」，安装包或内核程序（W1 起叫 `LightboatCore.exe`）被隔离 | 每个正式版发布后，把安装包提交到微软误报申诉（https://www.microsoft.com/wdsi/filesubmission ，免费，通常几天内处理）；教程里写「被隔离时如何恢复并添加排除项」 |
| **智能应用控制（Smart App Control）**（Windows 11 全新安装的电脑，默认处于评估 / 开启状态） | **直接阻止未签名程序运行，没有「仍要运行」按钮**。FlClash 已内置对应提示：「Windows 智能应用控制拦截了未签名的 FlClashCore.exe……」 | 只能让用户在「Windows 安全中心 → 应用和浏览器控制 → 智能应用控制」里关闭，而且**关闭后不能再打开**（除非重装系统）。这会劝退一部分用户 |

结论：内测阶段不签名可以接受；**正式对外推广前要重新评估签名**。可选方案（价格与条件以官方当时为准）：

- 微软 **Azure Artifact Signing**（原 Trusted Signing）：按月付费，价格低；需要组织或个人身份验证；签名后 SmartScreen 与智能应用控制都认；
- 传统 **OV 代码签名证书**：每年数百美元；新证书初期 SmartScreen 仍可能提示，随下载量积累信誉后消失。

签名一旦开始，就在 Actions 流程里加签名步骤（证书或签名凭据放 GitHub Secrets），三个可执行文件（主程序、内核、后台服务）和安装程序都要签。

## 6. 发布流程（Windows 部分）

与安卓发布一起进行（安卓 05 §5）：

1. Windows 回归用例（W5 §4）在运营方电脑上通过；
2. 改版本号、写更新说明，提交；
3. 打标签 `lb-v<版本>` 推送 → Actions 构建 Windows 产物并创建 GitHub Release；安卓 APK 照常在本机构建，手动附加到同一个 Release；
4. 把安装包、`SHA256SUMS` 上传到官网下载目录，最后更新 `latest.json`（主项目托管就绪后）：

```json
{
  "version": "1.0.0",
  "published_at": "2026-12-01",
  "notes": "· 首个 Windows 正式版",
  "android": { "...": "见安卓 05 §4" },
  "windows": {
    "min_supported": "0.4.0",
    "files": {
      "amd64-setup": { "url": "https://…/Lightboat-1.0.0-windows-amd64-setup.exe", "sha256": "…" },
      "amd64-zip":   { "url": "https://…/Lightboat-1.0.0-windows-amd64.zip", "sha256": "…" }
    }
  }
}
```

`latest.json` 的结构要和安卓那边商量后统一（整合后在 05 §4 定稿）。

5. 提交误报申诉（§5）。

## 7. GPL-3.0

与安卓相同：每个对外发布的版本在 GitHub Release 附上对应源码（标签即源码）；App「关于」里写明基于 FlClash（GPL-3.0）与 mihomo（GPL-3.0）并给出源码地址。
