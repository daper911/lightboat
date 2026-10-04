# 09 轻舟项目现状（与 App 相关的部分）

> 2026-10-04 的快照。最新情况以主项目 `/home/ubuntu/projects/vpn` 的 `docs/` 为准：`operations.md`（运维）、`payments.md`（支付）、`security.md`（安全）、`customizations.md`（对上游的改动）。

## 1. 整体

| 项目 | 现状 |
|---|---|
| 品牌 | 轻舟（Lightboat），运营主体 QINZHOU NETWORK CO.LLC |
| 面板 | PPanel（开源 VPN 面板，Go 后端 + React 前端）加上轻舟自己的改动，仓库 `git@github.com:daper911/mvpn.git` |
| 服务器 | HK1：AWS 香港，`43.199.68.186`，面板和节点都在这台上，全部用 Docker 运行 |
| 用户 | 尚未正式运营，目前只有测试账号 |
| 发布方式 | 开发阶段在本机构建镜像，直接部署到 HK1；打 v1.0.0 后改用正式流程（见主项目 `docs/roadmap/release-process.md`） |

## 2. 域名

| 用途 | 域名 | 说明 |
|---|---|---|
| 面板（网站与 API） | ssr.cnbetx.com | App 调用的所有接口 |
| 订阅下载 | sub.cnbetx.com | 只提供 `/api/subscribe`；旧的 `ssr.cnbetx.com/api/subscribe` 也能用 |
| 节点 | hk1.cnbetx.com | 以后按 jp1、sg1… 命名 |
| USDT 收银台 | pay.cnbetx.com | App 不直接用 |
| 发信 / 客服邮箱 | mail.cnbetx.com | 验证码邮件从 noreply@mail.cnbetx.com 发出；客服 support@mail.cnbetx.com |

DNS 托管在 Cloudflare，都只做解析（灰云，不走 Cloudflare 代理），因为 Cloudflare 免费版在国内访问慢。**面板目前没有备用域名**。

## 3. 节点

| 节点 | 协议 | 端口 | 说明 |
|---|---|---|---|
| 香港 HK1 · Reality | VLESS + Reality（xtls-rprx-vision，指纹 chrome，伪装 www.icloud.com） | 8443/TCP | 主力 |
| 香港 HK1 · Hysteria2 | Hysteria2（自签证书，靠证书指纹校验） | 8443/UDP | 弱网下更快 |

节点程序是 PPanel 官方的 ppnode（基于 Xray / sing-box），配置由面板下发。只有一个地区，以后计划增加节点，并把面板和节点分到不同服务器。

## 4. 账号与安全（App 必须适配）

- 登录方式只有邮箱 + 密码（手机号、第三方登录都没开）；
- 注册必须验证邮箱；
- **自建滑块验证码**（不用 Cloudflare Turnstile）：发邮箱验证码前必须过滑块；登录时同一邮箱或同一 IP 15 分钟内输错 3 次，就要先过滑块。账号不会被锁定；
- 同一 IP 24 小时最多注册 5 个账号；
- 所有接口按 IP 限流，超限返回 HTTP 429（JSON 正文 `code: 401`）；
- 管理员账号登录不触发滑块（管理后台暂时没有滑块）。

接口细节见 [02](02-panel-integration.md)。

## 5. 套餐与支付

- 套餐由运营方在后台手动维护（名称、价格、流量、多月折扣），**开发时不要改套餐数据**；
- 购买时可以选月付 / 季付 / 年付；
- 支付方式：
  - 余额；
  - USDT（TRC20 / BEP20，自建 EPUSDT，网站内直接显示收款地址和二维码）；
  - 支付宝 / 微信（第三方易支付商户 Futoon，跳转到收银台）；
- 流量用尽可以付费重置；**不支持退订**（运营规则：开通后不退款）。

App 第一版不做付款，「续费」直接用浏览器打开 `https://ssr.cnbetx.com/#/subscribe`。

## 6. 网站现在给安卓用户的引导

网站首页的「连接设备」里，安卓推荐的客户端依次是：Clash（FlClash / Clash Meta）、v2rayNG、Hiddify。下载链接目前**还是空的**（计划把安装包托管在自己的服务器上）。App 发布后，这里的首选改为「轻舟 App」。代码位置：主项目 `frontend/apps/user/src/config/clients.ts`。

## 7. 订阅模板

面板按 User-Agent 选择订阅模板（Clash、小火箭、sing-box、Stash、Surge 等），模板文件在主项目 `deploy/templates/`。Clash 模板输出 mihomo 配置，规则集从 `cdn.jsdmirror.com` 下载。App 使用 Clash 模板（UA 含 `Clash`）。

## 8. 运营方的工作习惯（AI 协作须知）

- 运营方**始终用中文交流**；
- 面板服务器只用 Docker，不在宿主机上装其他服务；
- 套餐由运营方手动管理，AI 不改套餐数据，也不对套餐内容发表意见；
- 密钥和密码不进 git：主项目本地的 `connect.md`、`key.env` 都已加入 .gitignore；
- 改服务器配置前先备份；本地和服务器保持一致；
- 有争议的方案先讨论、再动手；小而明确的改动可以直接做。
