# 05 构建、签名与发布

## 1. 签名证书（最重要，只做一次）

安卓用签名证书识别「同一个 App」。**证书丢了，已安装的用户就无法升级**，只能卸载重装（会丢失登录状态和设置）；证书泄露，别人就能做出冒充轻舟的「升级包」。

**2026-10-06 已生成**（运营方确认按以下参数）：PKCS12，RSA 4096，别名 `lightboat`，有效期到 2056-11-17（30 年；安卓只要求晚于 2033 年），主体 `CN=Lightboat, O=QINZHOU NETWORK CO.LLC`（公司名已作为 Windows 安装包发布者公开，所以写上；任何人都能从 APK 里读到主体信息）。证书指纹（SHA-256，公开信息，用来核对安装包是否正式签名）：

```
1F:69:E4:24:A5:76:03:0B:FF:DC:18:C1:9E:CA:22:2A:64:20:26:B6:02:E7:2C:D6:8E:2B:C1:1A:85:88:95:CB
```

生成命令（以后换证书时参考；**证书一旦用于发布就不要再换**）：

```bash
keytool -genkeypair -keystore android/app/keystore.jks -storetype PKCS12 -alias lightboat \
  -keyalg RSA -keysize 4096 -validity 11000 \
  -dname "CN=Lightboat, O=QINZHOU NETWORK CO.LLC" \
  -storepass:file <密码文件> -keypass:file <密码文件>
```

PKCS12 格式要求证书密码和密钥密码相同。

保管（三处，至少一处不在服务器上）：

| 存放位置 | 内容 | 说明 |
|---|---|---|
| 服务器，工作副本 | `android/app/keystore.jks`；密码在 `android/local.properties`（`storePassword`、`keyAlias`、`keyPassword`） | 构建正式包时直接读取；两者都被 `.gitignore` 排除，权限 600。**绝不提交到 git** |
| 服务器，仓库外主副本 | `~/.lightboat/lightboat-release.jks`、`~/.lightboat/signing.properties` | 防止清理仓库目录时误删工作副本 |
| 运营方的 1Password | 证书文件（附件）与密码、别名、R2 备份解密口令 | **这是唯一能救命的副本**。2026-10-06 已准备好文件（仓库根目录的 `signing-backup/`，只在本机、被 `.git/info/exclude` 排除），运营方说晚一点上传；**上传后删除 `signing-backup/`** |
| Cloudflare R2 私有桶 `mvpn-backups` | `lightboat-signing/lightboat-keystore-20261006.jks.enc`（openssl AES-256-CBC、PBKDF2 60 万次） | 解密口令在 `key.env` 的 `LIGHTBOAT_SIGNING_PASSPHRASE` 和 1Password；上传后下载解密核对过，与原件一致。**不要放进公开桶 `qzvpn`** |

恢复：从 R2 下载 → `openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 -in <文件> -out android/app/keystore.jks -pass pass:<口令>` → 按 1Password 里的密码写回 `android/local.properties`。

FlClash 的构建脚本（`android/app/build.gradle.kts`）发现 `android/app/keystore.jks` 和这三项密码齐全时，正式构建用正式签名和正式包名 `com.lightboat.app`；缺任何一项就退回开发签名并加 `.dev` 后缀。**构建后要核对包名和证书指纹**（`apksigner verify --print-certs`）。

## 2. 版本号

> Android 与 Windows **共用**这个版本号（一套代码，一个版本号），见 [windows/W4 §4](windows/W4-build-and-ci.md)。

- `versionName` 用语义化版本：`0.1.0`（原型）→ `0.x`（内测）→ `1.0.0`（正式发布）；
- `versionCode` 单调递增的整数，**每次发出去的包都必须比上一次大**，否则手机拒绝覆盖安装；
- 版本号写在 `pubspec.yaml` 的 `version: 0.1.0+1`（`+` 后面是 versionCode）；
- 每个发出去的版本打 git 标签 `lb-v0.1.0`（加 `lb-` 前缀，避免和上游 FlClash 的 `v0.8.x` 标签混淆）。

## 3. 构建产物

| ABI | 是否发布 | 说明 |
|---|---|---|
| arm64-v8a | ✅ 必须 | 2017 年以后的绝大多数手机 |
| armeabi-v7a | ✅ 建议 | 老旧机型 |
| x86_64 | ❌ | 只有模拟器和极少数平板需要 |

文件命名：`Lightboat-<版本>-android-<abi>.apk`，同时生成 `SHA256SUMS`。

## 4. 分发与检查更新

2026-10-05 运营方决定：安装包与 `latest.json` 放在 Cloudflare R2 桶 `qzvpn`，经自定义域名 `cdn.cnbetx.com` 公开访问（桶是公开的，不要放私密文件）。安卓与 Windows 共用一份 `latest.json`：

```
https://cdn.cnbetx.com/lightboat/
  ├─ latest.json
  ├─ android/Lightboat-<版本>-android-arm64-v8a.apk
  └─ windows/Lightboat-<版本>-windows-amd64-setup.exe
```

```json
{
  "version": "0.3.1",
  "build": 4,
  "min_build": 1,
  "published_at": "2026-10-05",
  "notes": "· 修复全局模式\n· 首次连接更快",
  "android": {"version": "0.3.1", "build": 4, "arm64-v8a": {"url": "https://cdn.cnbetx.com/lightboat/android/…apk", "sha256": "…"}},
  "windows": {"version": "0.3.1", "build": 4, "amd64-setup": {"url": "https://cdn.cnbetx.com/lightboat/windows/…exe", "sha256": "…"}}
}
```

- **每个平台的条目带自己的 `version` / `build`**（两个平台的安装包不一定同时就绪，Windows 要等云端构建）；App 优先读本平台的，没有才读顶层。**顶层的 `version` / `build` 取两个平台中较旧的那个**：0.4.0 及以前的 App 只读顶层，这样某个平台的新包还没上传时只会晚一点提示，不会出现「更新了还是旧版」的循环（2026-10-05 出过一次：本地 pubspec 已升到 0.4.1，脚本却上传了云端构建的 0.4.0 Windows 包；已修，并加了 `--version`）；

- `build` 是 `pubspec.yaml` 版本号 `+` 后面的数字，两个平台比较同一个数；低于 `min_build` 的版本强制更新（弹窗不能关闭）；
- **安卓安装包里的 versionCode 不等于这个数**：按 CPU 架构分包时 Flutter 会加上「架构编号 × 1000」（arm64-v8a 是 2，所以 build 7 的 versionCode 是 2007）。App 比较前先对 1000 取余（`lbInstalledBuild`）；0.5.0 之前的安卓版没有这一步，读到的是 2005、2006，**永远不会提示更新**（2026-10-06 发现并修复）；
- App（`lib/lightboat/update.dart`）进入首页后自动检查，最多 12 小时一次，有新版本才弹窗；「我的 → 检查更新」手动检查；
- 第一版点「下载」用系统浏览器下载安装包（安卓下载完点通知安装，Windows 运行安装程序）。App 内下载、校验 sha256、直接调起安装留到以后（需要安卓安装权限）；
- 发布：`python3 tool/lightboat/publish_r2.py --notes "…" --android dist/….apk --windows ….exe`（读 `key.env` 里的 R2 密钥，需要 `boto3`；只传一个平台时保留另一个平台的条目）。**上传的安装包不是本地刚构建的（例如从 Actions 下载的 Windows 包）时，必须用 `--version X.Y.Z+N` 写明它的版本**，否则会按本地 `pubspec.yaml` 的版本命名。

- **下载损坏**（2026-10-05 三星 A15 上遇到）：手机上下载的 APK 大小正确、内容却坏了，安装提示「package appears to be invalid」，真实错误是 `INSTALL_PARSE_FAILED_NO_CERTIFICATES … sha-256 digest of contents did not verify`。重新下载即可。排查用校验页 `https://cdn.cnbetx.com/lightboat/check.html`（在手机浏览器里算所选 APK 的 SHA-256，与已发布版本对比，文件不上传；页面目前手工生成，发新版后要更新里面的指纹）。安装教程要写上「装不上先用校验页核对，坏了就删掉重下；三星手机可关闭『下载加速器』」；
- Cloudflare 会缓存 `cdn.cnbetx.com` 上的 APK（包括响应头），**同名文件不要覆盖**，每个版本用新文件名；现有令牌没有清缓存的权限，必要时在链接后加 `?v=N` 绕过。

网站「连接设备 → Android / Windows」的下载按钮可以直接指向上面的地址（需要主项目改，02 §9 第 1 条）。

## 5. 发布流程（每个版本）

> Windows 产物由标签触发云端构建并创建 GitHub Release，APK 附加到同一个 Release；Windows 部分见 [windows/W4 §6](windows/W4-build-and-ci.md)。`latest.json` 增加 windows 段，结构在首次发布 Windows 前与本节一起定稿。

1. 在主分支确认 [06](06-testing.md) 的回归用例都通过；
2. 修改 `pubspec.yaml` 的版本号，写更新说明；
3. 用正式证书构建 arm64-v8a 和 armeabi-v7a；
4. 计算 SHA256，上传 APK、`SHA256SUMS`，最后才更新 `latest.json`（保证 App 拿到的地址一定已经可以下载）；
5. 打标签 `lb-v<版本>` 并推送；GitHub 仓库发布对应 Release（满足开源义务）；
6. 自己的手机从旧版本升级一次，确认能覆盖安装、登录状态还在。

## 6. GPL-3.0 开源义务

FlClash 和 mihomo 都是 GPL-3.0，我们的修改版同样适用：

- 对外分发 APK 时，必须让拿到 APK 的人能获得**对应版本的完整源码**：公开 GitHub 仓库，并给每个发布版本打标签；
- 保留原有的许可证文件与版权声明；
- App 的「关于 → 开源许可」里写明：基于 FlClash（GPL-3.0）、mihomo（GPL-3.0），附上本项目源码地址；
- 签名证书、面板地址列表的签名私钥、任何密码**不属于源码**，不要提交。

## 7. 风险提示

- 安装时系统会提示「未知来源」，部分国产系统还会提示「风险应用」或要求「纯净模式」验证，需要配图文安装教程；
- 自有 App 会让运营主体更容易被识别（包名、证书、关于页），发布前结合合规风险评估；
- FlClash 上游每年都会适配新的 Android 版本，我们要跟进合并，否则新系统上可能出问题。
