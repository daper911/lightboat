# 04 开发环境搭建（从零开始）

> 目标：在现有的开发机（就是放轻舟主项目的这台 Ubuntu 服务器）上，用 Docker 搭好安卓构建环境，能打出 APK 并装到手机上。**不需要另配电脑**，你也不需要在本地装 Android Studio。

## 0. 前提

| 项目 | 现状（2026-10-04） |
|---|---|
| 机器 | 4 核、15 GB 内存、约 133 GB 可用磁盘，x86_64，Ubuntu 26.04 |
| Docker | 29.x；当前账号运行 docker 需要 `sudo` |
| GitHub | 本机已能用 SSH 推送 `daper911` 名下的仓库 |
| KVM | **没有**，所以跑不了安卓模拟器，**测试只能用真机** |
| 编辑器 | 你用 VS Code 远程连接这台机器 |

工具链版本以 FlClash 的正式构建为准：**Flutter 3.47.4、Go 1.26.4、JDK 17、Android SDK（platform 37、build-tools）、NDK 28.2.13676358、Rust stable**。全部装在容器里，不污染宿主机，也不影响机器上的其他服务。首次搭建加全量编译约半天，之后每次打包十几分钟。

## 1. 建仓库（你来操作，约 5 分钟）

1. 浏览器打开 https://github.com/chen08209/FlClash ，点右上角 **Fork**：
   - Owner：`daper911`
   - Repository name：`lightboat-android`
   - 勾选「Copy the main branch only」
2. 可见性：Fork 公开仓库默认就是公开的。GPL-3.0 要求**对外分发 APK 时公开对应源码**，所以公开没有问题。如果开发期间不想公开：先不 Fork，改为在 GitHub 新建一个空的私有仓库 `lightboat-android`，再告诉 AI「用导入方式创建」（AI 会把 FlClash 的代码推进去）。
3. 告诉 AI 仓库已经建好。

> 2026-10-04 实际采用的是私有仓库 + 导入方式：`origin` 是 `git@github.com:daper911/lightboat-android.git`，`upstream` 是 FlClash。对外分发 APK 之前要把仓库改为公开（05 §6）。

## 2. 克隆到本机（AI 来做）

```bash
cd /home/ubuntu/projects
# 这个文件夹目前只有文档：先挪开，克隆仓库后再把文档原样放回去
mv lightboat-android lightboat-android-docs
git clone --recursive git@github.com:daper911/lightboat-android.git
cd lightboat-android
git remote add upstream https://github.com/chen08209/FlClash.git
mkdir -p docs && cp -r ../lightboat-android-docs/docs/lightboat docs/
cp -r ../lightboat-android-docs/env ../lightboat-android-docs/CLAUDE.md .
git add CLAUDE.md env docs/lightboat && git commit -m "Add Lightboat docs and build environment"
rm -rf ../lightboat-android-docs     # 确认文档已在新仓库里之后再删
```

文档在本文件夹里的位置（`CLAUDE.md`、`docs/lightboat/`、`env/`）就是它们在仓库里的最终位置，拷过去以后相对链接仍然有效。FlClash 自己的 `README.md`、`AGENTS.md` 保持不动。

- 子模块 `core/Clash.Meta` 的地址是 SSH 格式（`git@github.com:chen08209/Clash.Meta.git`）。本机已有 GitHub SSH 密钥，可以直接克隆。在没有 SSH 密钥的机器上，先执行 `git config --global url."https://github.com/".insteadOf git@github.com:`。
- FlClash 仓库里已经有自己的 `AGENTS.md`；我们的 `CLAUDE.md` 放在根目录，两者并存（`CLAUDE.md` 里写明 FlClash 的规则同样适用）。

## 3. 构建环境（Docker 镜像）

镜像定义在 [env/Dockerfile](../../env/Dockerfile)（草稿，第一次搭建时验证并修正）。内容要点：

- 基础镜像 Ubuntu 24.04；
- JDK 17（Temurin 或 OpenJDK）；
- Android 命令行工具，再装 `platform-tools`、`platforms;android-37`、`build-tools;37.x`、`ndk;28.2.13676358`；
- Flutter 3.47.4（固定版本）、Go 1.26.4、Rust stable（rustup，添加 Android 目标）；
- 缓存目录都挂成 Docker 卷，避免每次重新下载：Gradle（`~/.gradle`）、pub（`~/.pub-cache`）、Go（`~/go/pkg/mod`）、Cargo（`~/.cargo/registry`）。

```bash
cd /home/ubuntu/projects/lightboat-android
sudo docker build -t lightboat-android-env -f env/Dockerfile env/
```

实测（2026-10-04）：镜像约 3.3 GB，构建约 10 分钟。

日常在容器里执行命令用 [env/run.sh](../../env/run.sh)，它挂好了各个缓存卷，并在结束后把容器写出的文件交还给当前用户：

```bash
env/run.sh flutter test
env/run.sh dart setup.dart android --arch arm64
```

`lb-android` 卷保存 debug 签名证书（`~/.android/debug.keystore`），保证每次开发构建的签名一致、能覆盖安装。**不要删除这个卷**，否则手机上的测试包要先卸载才能装新包。

## 4. 第一次构建 APK

```bash
cd /home/ubuntu/projects/lightboat-android
sudo docker run --rm -it \
  -v "$PWD":/work -w /work \
  -v lb-gradle:/root/.gradle -v lb-pub:/root/.pub-cache \
  -v lb-go:/root/go -v lb-cargo:/root/.cargo/registry \
  lightboat-android-env \
  bash -lc 'flutter pub get && dart setup.dart android --arch arm64'
# 产物：dist/*.apk
```

- 先用**原版 FlClash 代码、不做任何改动**构建一次，确认环境没问题（这就是里程碑 M0 的验收）；
- 加 `--arch arm64` 只打主流手机用的 arm64 包，速度快一倍；
- 第一次构建会编译 Go 内核和 Rust 库，较慢（30–60 分钟），之后只编译改动的部分；
- 没有签名证书时，release 包会构建失败或者是未签名的。开发期间先用 debug 构建（`flutter build apk --debug` 或 setup.dart 的对应参数），正式签名见 [05](05-build-and-release.md)。

失败时先看：

- `.dart_tool/setup_build_cache/hook.log`：Go / Rust 内核的构建日志；
- 内存不够（15 GB 一般够）：在 `android/gradle.properties` 里调小 `org.gradle.jvmargs`，或者关掉宿主机上暂时不用的容器；
- 依赖下载慢：这台机器在境外，直接访问 Google / GitHub 没问题；如果以后换到国内机器，要配置 Flutter、Gradle、Go 的国内镜像。

## 5. 装到手机上

没有模拟器，按下面的方法把 APK 装到真机上：

**方法一（推荐，最简单）**：在 VS Code 左侧文件树里找到 `dist/xxx.apk`，右键 → **Download…** 下载到你的电脑；再用微信或 QQ 的「文件传输助手」发到手机，或者用数据线拷过去，在手机上点开安装（需要允许「安装未知来源应用」）。

**方法二（适合频繁测试）**：AI 把测试包上传到一个临时下载地址，比如主项目 R2 里的单独目录、带过期时间的链接，你在手机浏览器打开下载。这需要先在主项目里配好托管，见 [02 §9](02-panel-integration.md)。

**方法三（需要你的电脑）**：你的电脑装上 Android platform-tools，手机开启「USB 调试」，用 `adb install xxx.apk` 安装，用 `adb logcat` 看实时日志。排查闪退、连不上这类问题时最有用。

**看日志**：App 里会做「导出日志」（P0 功能），出问题时导出发给 AI 即可。

## 6. VS Code 编辑体验（可选）

想要 Dart 代码补全、跳转、实时报错，需要 VS Code 能找到 Flutter SDK。两种做法：

1. **开发容器（推荐）**：安装 VS Code 的「Dev Containers」扩展，用 [env/devcontainer.json](../../env/devcontainer.json)（复制到仓库的 `.devcontainer/devcontainer.json`），然后执行「Reopen in Container」。前提是当前账号可以不加 sudo 使用 docker：`sudo usermod -aG docker ubuntu`，然后重新登录。注意：加入 docker 组约等于给了 root 权限，这台机器只有你自己用的话问题不大。
2. **宿主机也装一份 Flutter SDK**（只用于编辑器分析，不用来构建）：解压 Flutter 3.47.4 到 `~/flutter`，在 VS Code 设置里把 `dart.flutterSdkPath` 指过去。

两种都不做也能开发：代码由 AI 编写，构建和测试都在容器里完成。

## 7. 日常循环

```
改代码 → 容器内 flutter analyze / flutter test → 构建 APK → 装到手机 → 验证 / 导出日志 → 下一轮
```

常用命令（都在容器内执行）：

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # 改了模型 / provider / 数据库后
flutter analyze
flutter test
dart setup.dart android --arch arm64                         # 打包
```

具体以 FlClash 仓库 `.agents/commands.md` 为准。
