# 02 面板对接契约

> 2026-10-04 在线上（https://ssr.cnbetx.com，PPanel + 轻舟改动）逐项核实。面板源码在主项目 `vpn/backend/`，前端的接口类型定义在 `vpn/frontend/packages/ui/src/services/{common,user}/typings.d.ts`，以它们为准。

## 1. 基本约定

| 项目 | 值 |
|---|---|
| 面板地址 | `https://ssr.cnbetx.com`（以后可能增加备用地址，见 [03 §5](03-architecture.md)） |
| 订阅地址 | `https://sub.cnbetx.com/api/subscribe?token=<订阅token>` |
| 数据格式 | JSON，UTF-8 |
| 鉴权 | 请求头 `Authorization: <JWT>`，**直接放 token，不加 `Bearer ` 前缀** |
| 统一响应 | `{"code": 200, "msg": "success", "data": {...}}`。**业务错误也是 HTTP 200**，靠 `code` 区分；只有被限流时是 HTTP 429（正文仍是同样的 JSON） |
| 时间 | 毫秒时间戳（`expire_time`、`created_at` 等）；订阅响应头里的 `expire` 是**秒** |
| 流量 | 字节 |
| 金额 | 分（整数），币种 CNY |
| User-Agent | App 统一使用 `Lightboat-<平台>/<版本号> (Clash.Meta)`，平台为 `Android` 或 `Windows`（W1 起），**必须包含 `clash`**（不区分大小写），原因见 §5 |

## 2. 接口清单（App 用到的）

| 用途 | 方法与路径 | 需要登录 | 优先级 |
|---|---|---|---|
| 站点配置（站点名、订阅域名、注册设置等） | `GET /v1/common/site/config` | 否 | P0 |
| 获取滑块验证码 | `GET /v1/common/captcha/slide` | 否 | P0 |
| 校验滑块 | `POST /v1/common/captcha/slide/verify` | 否 | P0 |
| 登录 | `POST /v1/auth/login` | 否 | P0 |
| 用户信息 | `GET /v1/public/user/info` | 是 | P0 |
| 我的订阅（含订阅 token、到期、流量） | `GET /v1/public/user/subscribe` | 是 | P0 |
| 公告 | `GET /v1/public/announcement/list?page=1&size=20` | 是 | P1 |
| 心跳（探测面板地址是否可用） | `GET /v1/common/heartbeat` | 否 | P0（域名容灾用） |
| 下载订阅配置 | `GET https://sub.cnbetx.com/api/subscribe?token=…` | 否（订阅 token 本身就是凭据） | P0 |

不要使用：`/v1/auth/login/device`（设备登录，面板未开启）、任何 `/v1/admin/*` 接口。

### 2.1 登录

```http
POST /v1/auth/login
Content-Type: application/json

{"email": "user@example.com", "password": "******", "captcha_ticket": "可选"}
```

成功：

```json
{"code": 200, "msg": "success", "data": {"token": "<JWT，约 230 字符>"}}
```

- `captcha_ticket`：只有面板要求时才带（见 §6）。
- JWT 有效期 **7 天**（面板配置 `JwtAuth.AccessExpire = 604800` 秒）。
- 返回的数据里还可能有 `third_party_bindings`（第三方登录绑定），App 不用处理。

### 2.2 用户信息

`GET /v1/public/user/info` → `data` 主要字段：`id`、`auth_methods`（数组，元素为 `{auth_type, auth_identifier, verified}`；`auth_type == "email"` 那一项的 `auth_identifier` 就是登录邮箱）、`balance`（余额，分）、`enable`、`is_admin`、`created_at`。

### 2.3 我的订阅

`GET /v1/public/user/subscribe` → `{"list": [UserSubscribe...], "total": n}`

| 字段 | 含义 |
|---|---|
| `id` | 用户订阅 id |
| `token` | **订阅 token**，拼接订阅地址用；用户在网站上「更换订阅链接」后会变 |
| `short` | 短标识（App 用不到） |
| `status` | 0 待生效、1 **有效**、2 已完成、3 **已过期**、4 已被抵扣（不展示）、5 已停用 |
| `expire_time` | 到期时间，毫秒；`0` 表示不限期 |
| `traffic` | 总流量，字节；`0` 表示不限量 |
| `upload` / `download` | 本周期已用的上行 / 下行流量，字节 |
| `reset_time` | 下次流量重置时间，毫秒（没有则为 0） |
| `subscribe.name` | 套餐名 |
| `subscribe.sell` | 套餐是否仍在售（不在售就不显示「续费」） |

展示规则（与网站首页一致）：

- 过滤掉 `status == 4`；
- 已过期 = `status == 3 && expire_time != 0`；
- 流量用尽 = `traffic > 0 && upload + download >= traffic`；
- 7 天内到期时显示提醒。

### 2.4 公告

`GET /v1/public/announcement/list?page=1&size=20` → `{"total": n, "announcements": [{id, title, content, pinned, popup, show, created_at, updated_at}]}`。`content` 是 Markdown；`popup=true` 的启动时弹一次（用 id 记住已读）。

### 2.5 站点配置

`GET /v1/common/site/config`，App 关心的字段：

- `site.site_name`：「轻舟」；
- `subscribe.subscribe_domain`：订阅域名，目前为 `sub.cnbetx.com`，可能是多行；为空时用面板域名；
- `subscribe.subscribe_path`：`/api/subscribe`；
- `currency.currency_unit` / `currency_symbol`：`CNY` / `¥`。

**订阅地址的拼法**（与网站一致）：`https://<subscribe_domain 第一行><subscribe_path>?token=<token>`。

### 2.6 注册、购买与付款（2026-10-04 按网站源码核对）

| 用途 | 方法与路径 | 说明 |
|---|---|---|
| 发注册验证码 | `POST /v1/common/send_code {email, type: 1, captcha_ticket}` | 必须先过滑块；60 秒一次（`verify_code.verify_code_interval`） |
| 注册 | `POST /v1/auth/register {email, password, code, invite?, captcha_ticket?}` | 成功直接返回 `data.token`（JWT）；返回 110001 时过滑块重试 |
| 套餐列表 | `GET /v1/public/subscribe/list` | 需要登录；只展示 `sell && show`；`discount[]` 是 `{quantity, discount}`，discount 为折后百分比 |
| 支付方式 | `GET /v1/public/portal/payment-method` | `id == -1` 是余额；`platform` 为 `GMPay`、`Cryptomus` 的是加密货币，其余是在线支付（易支付） |
| 询价 | `POST /v1/public/order/pre {subscribe_id, quantity, payment, user_subscribe_id?}` | 金额以它为准（分） |
| 新购 | `POST /v1/public/order/purchase {subscribe_id, quantity, payment}` → `order_no` | |
| 续费 | `POST /v1/public/order/renewal {user_subscribe_id, quantity, payment}` → `order_no` | 只在原套餐仍在售时可用，否则走新购 |
| 发起支付 | `POST /v1/public/portal/order/checkout {orderNo, returnUrl}` | `type`：`url`（打开 `checkout_url`）、`qr`、`crypto`（`crypto{address, amount, token, network, fiat, currency, expires_at 秒}`）、`balance` |
| 订单状态 | `GET /v1/public/order/detail?order_no=` | `status`：1 待支付、2 已支付、3 已取消、4 已关闭、5 已完成 |

新增错误码（App 已翻译成中文）：20001 / 90011 邮箱已注册、20005 余额不足、20006 关闭注册、20009 邀请码错误、60002 套餐不可购买、60007 售罄、70001 验证码错误、90015 当日发送次数超限。

## 3. 错误码

| code | 含义 | App 处理 |
|---|---|---|
| 200 | 成功 | |
| 400 | 参数错误 | 提示「请求有误」，记日志 |
| 401 | **请求过于频繁**（也是 HTTP 429 的正文） | 提示「操作太频繁，请稍后再试」，不要自动重试 |
| 500 | 服务器错误 | 提示稍后再试；订阅相关的操作继续用缓存 |
| 20002 | 用户不存在 | 「账号不存在」（面板有意如实提示） |
| 20003 | 密码错误 | 「密码错误」 |
| 20004 | 账号已被禁用 | 「账号已被停用，请联系客服」 |
| 40002 / 40003 / 40004 / 40005 | token 为空 / 无效 / 过期 / 无权限 | 清除 JWT，需要账号数据时引导重新登录；**不要断开已有连接** |
| 110001 | 需要滑块验证码 | 弹出滑块，拿到 ticket 后带上 `captcha_ticket` 重试一次 |
| 110002 | 滑块校验未通过 | 换一张图重来 |

## 4. 两种凭据：JWT 与订阅 token

这是 App 设计里最重要的一点：

| | JWT（登录 token） | 订阅 token |
|---|---|---|
| 来源 | 登录接口 | `/v1/public/user/subscribe` 返回的 `token` |
| 有效期 | 7 天 | 长期有效，直到用户在网站上点「更换订阅链接」 |
| 用途 | 账号相关接口（用户信息、订阅列表、公告） | 下载节点配置（订阅地址） |

所以：

- **连接功能只依赖订阅 token**。JWT 过期后，App 依然能更新订阅、正常连接，不应该把用户「踢出去」。
- 套餐信息在 JWT 有效时来自 `/v1/public/user/subscribe`；JWT 过期后，用订阅响应头 `subscription-userinfo` 里的流量和到期时间兜底（见 §5），只在用户进入需要账号数据的页面时才提示重新登录。
- 订阅下载返回 404 或内容为空，通常是用户在网站上更换了订阅链接（旧 token 作废）：这时需要用 JWT 重新拉取订阅列表；JWT 也失效的话，才要求重新登录。
- 两个 token 都要存在加密存储里。导出日志时，订阅地址和 token 必须打码。

## 5. 订阅（节点配置）

```http
GET https://sub.cnbetx.com/api/subscribe?token=<订阅token>
User-Agent: Lightboat-Android/0.1.0 (Clash.Meta)
```

- 面板**按 User-Agent 选择输出格式**：UA 里包含 `clash`（不区分大小写）时，返回 mihomo / Clash.Meta 的 YAML 配置；否则返回 base64 编码的通用链接列表，App 无法直接使用。2026-10-04 实测：`FlClash/0.8.99`、`Lightboat-Android/0.1 (Clash; mihomo)` 都返回 YAML，`lightboat/0.1` 返回 base64。
- 实测响应头：

  ```
  content-type: text/plain; charset=utf-8
  content-disposition: attachment;filename*=UTF-8''%E8%BD%BB%E8%88%9F        # 文件名「轻舟」
  subscription-userinfo: upload=266054;download=266768625;total=107374182400;expire=1793621522
  ```

  `subscription-userinfo` 是业界通用的写法：`upload`、`download`、`total` 单位是字节，**`expire` 单位是秒**。
- YAML 的顶层字段：`mode, allow-lan, bind-address, mixed-port, log-level, unified-delay, tcp-concurrent, external-controller, tun, dns, proxies, proxy-groups, rules, rule-providers, url-rewrite`。文件约 260 行，第一行是注释：`# 轻舟-<套餐名>`。
- 节点（2026-10-04 只有 2 个，都在香港 HK1 的 8443 端口）：
  - `香港 HK1 · Reality`：`type: vless`，`flow: xtls-rprx-vision`，`tls: true`，带 `reality-opts`（public-key、short-id）和 `client-fingerprint`；
  - `香港 HK1 · Hysteria2`：`type: hysteria2`，自签证书，靠 `fingerprint`（证书指纹）校验。
- 分组：`🚀 Proxy`（select，**第一个选项就是 `🌏 Auto`**），`🌏 Auto`（url-test，自动测速选最快），以及 `🍎 Apple`、`🔍 Google`、`📺 GlobalMedia`、`🤖 AI`、`🇨🇳 China` 等按应用分流的分组。
  - **首页的「线路」= `🚀 Proxy` 分组**：默认选 `🌏 Auto`；用户手动选节点，就是把 `🚀 Proxy` 切到具体节点。按应用分流的分组（`🔍 Google`、`📟 Telegram`、`🐠 Final` 等）第一个选项都是 `🚀 Proxy`，所以默认跟着线路走（2026-10-05 核对主项目 `deploy/templates/clash.gotmpl`）。
  - 线路列表**不显示**最终走直连的选项（`🎯 Direct`，以及类型为 Direct / Reject 的项），见 `lbLineChoices`。
  - **全局模式**：订阅里没有 `GLOBAL` 分组，mihomo 会自动生成一个，第一个选项是 `DIRECT`（`config/config.go`）。App 在配置的已选记录里把 `GLOBAL` 固定为 `🚀 Proxy`（`lbSelectedMap`），切到全局时若内核里还不是，就立即改过来。0.3.0 及以前没有这一步，「全局」实际是全部直连（2026-10-05 运营方在国内的 Windows 上遇到：测速正常、浏览器和 Telegram 打不开）。
- 规则集（`rule-providers`）从 **`cdn.jsdmirror.com`**（国内可访问的 jsDelivr 镜像）下载，共 20 个。这是外部依赖：镜像挂了，规则就加载不了。**建议 App 内置一份规则集作为兜底**，或者以后由面板托管规则集。
- 配置里的 `tun`、`dns`、`mixed-port`、`external-controller` 等设置，FlClash 会按自己的 VPN 实现覆盖掉，沿用 FlClash 的处理即可。

订阅更新频率：启动时更新一次，之后每 6 小时一次。面板对订阅接口按 IP 限流（30 次/分钟），正常使用碰不到。

## 6. 滑块验证码

面板自建了滑块拼图验证码（基于 go-captcha）。App 只在面板返回 `110001` 时才需要它。目前 App 能触发的只有登录：**同一邮箱或同一 IP 在 15 分钟内输错 3 次**后，下一次登录必须带 `captcha_ticket`。

### 6.1 流程

1. `GET /v1/common/captcha/slide` →

   ```json
   {"code": 200, "data": {
     "id": "32 位十六进制",
     "image": "data:image/jpeg;base64,...",
     "thumb": "data:image/png;base64,...",
     "thumb_x": 5, "thumb_y": 72, "thumb_width": 65, "thumb_height": 65
   }}
   ```

   - `image`：300×220 的背景图，上面有拼图缺口；
   - `thumb`：拼图块（PNG，带透明），初始位置是 (`thumb_x`, `thumb_y`)。
2. 用户横向拖动拼图块，纵坐标固定为 `thumb_y`。
3. 松手后提交拼图块**左上角在原图坐标系（300×220）中的位置**：

   ```http
   POST /v1/common/captcha/slide/verify
   {"id": "...", "x": 192, "y": 72}
   ```

   成功：`{"code": 200, "data": {"ticket": "32 位十六进制"}}`；失败：`{"code": 110002}`。
4. 带上 ticket 重试原来的请求：`{"email": ..., "password": ..., "captcha_ticket": "..."}`。

### 6.2 规则（面板端实现，App 要配合）

- 每张图**只能提交一次**，答错就作废，要重新获取一张；
- 横向误差在 **5 像素**以内算通过（以 300 像素宽的原图为准；屏幕上缩放显示时，要换算回原图坐标）；
- 从获取图片到提交**不能少于 0.4 秒**，否则判为机器；
- ticket 5 分钟内有效，只能用一次；
- 获取图片按 IP 限流（20 次/分钟）。

### 6.3 App 实现建议

- 用 Flutter 原生实现：`Image.memory` 画背景，`Positioned` 画拼图块，下面放一条滑轨；滑块位移按比例映射到拼图块的 x。
- 滑块位移到拼图 x 的映射：`x = thumb_x + 位移 × (300 − thumb_width − thumb_x) / (滑轨宽 − 滑块宽)`。这和网站用的 go-captcha-react 是同一个算法，可以参考 `vpn/frontend/apps/user/src/components/slide-captcha.tsx`。
- 提供「换一张」和「关闭」；答错时提示「没对准，换一张再试试」并自动换图。

## 7. 限流（面板入口 nginx，按客户端 IP）

| 接口 | 限制 |
|---|---|
| `/v1/auth/`（登录） | 20 次/分钟，突发 10 |
| `/v1/common/captcha/` | 20 次/分钟 |
| 其他 `/v1`、`/v2` 接口 | 10 次/秒，突发 40 |
| `/api/subscribe` | 30 次/分钟 |

超出限制返回 HTTP 429 和 `{"code":401,"msg":"Too Many Requests"}`。App 不要做激进的自动重试，失败退避至少 30 秒。

## 8. 外部链接（App 用浏览器打开）

| 用途 | 地址 |
|---|---|
| 注册 / 找回密码 | `https://ssr.cnbetx.com/#/auth` |
| 购买 / 续费 | `https://ssr.cnbetx.com/#/subscribe` |
| 订单与钱包 | `https://ssr.cnbetx.com/#/order` |
| 使用教程 | `https://ssr.cnbetx.com/#/document` |
| 工单 | `https://ssr.cnbetx.com/#/ticket` |
| 服务条款 / 隐私政策 | `https://ssr.cnbetx.com/#/tos`、`https://ssr.cnbetx.com/#/privacy-policy` |
| 客服邮箱 | support@mail.cnbetx.com |

网站使用 hash 路由（`#/…`）。网页的登录态和 App 不共享，用户在网页上需要再登录一次（第一版可以接受）。

## 9. 需要面板配合的事项

这些都在主项目 `vpn` 里改，不在本项目里做：

| # | 事项 | 何时需要 |
|---|---|---|
| 1 | **APK、Windows 安装包与 `latest.json` 的托管**：比如 `https://ssr.cnbetx.com/downloads/{android,windows}/`（web 容器的静态目录，或 R2），网站「连接设备」的安卓 / Windows 下载按钮指向它；`latest.json` 含 android 与 windows 两段（[05 §4](05-build-and-release.md)、[windows/W4 §6](windows/W4-build-and-ci.md)）。运营方 2026-10-04 决定网站客户端下载暂时搁置 | 第一次对外分发前 |
| 2 | 延长 JWT 有效期（例如 30 天），或者给 App 提供 refresh token | 体验优化，不阻塞 |
| 3 | 备用面板地址（另一个域名，最好走 CDN）与远程地址列表（见 [03 §5](03-architecture.md)） | 正式发布前 |
| 4 | 面板托管规则集，摆脱对 cdn.jsdmirror.com 的依赖 | 可选 |
| 5 | 订阅模板里给 App 单独一套（如果以后需要和 FlClash 用户的配置不同）：在面板「订阅模板」里加一行 UA 匹配 `Lightboat` | 可选 |
