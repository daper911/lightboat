import 'package:fl_clash/lightboat/api/panel_api.dart';

/// Lightboat's own copy, kept out of FlClash's ARB files so upstream merges
/// never conflict on them. Chinese only until English lands (P1).
abstract final class LbStrings {
  static const appName = '轻舟';
  static const slogan = '轻舟已过万重山';

  static const email = '邮箱';
  static const password = '密码';
  static const login = '登录';
  static const forgotPassword = '忘记密码';
  static const agreePrefix = '登录即表示同意';
  static const tos = '服务条款';
  static const privacy = '隐私政策';
  static const emailRequired = '请输入邮箱和密码';

  static const captchaTitle = '安全验证';
  static const captchaHint = '拖动下方滑块，把拼图移到缺口处。';
  static const captchaFailed = '没对准，换一张再试试。';
  static const captchaRefresh = '换一张';
  static const captchaLoadFailed = '验证码加载失败，请稍后再试';

  static const disconnected = '未连接';
  static const connecting = '正在连接…';
  static const connected = '已连接';
  static const connect = '连接';
  static const disconnect = '断开';
  static const vpnTitle = '创建本地 VPN';
  static const vpnExplain =
      '轻舟需要创建一个本地 VPN 才能为你加密连接，不会读取你的数据。\n\n接下来系统会询问是否允许，请点「确定」。';
  static const continueText = '继续';

  static const line = '线路';
  static const autoLine = '自动选择最快';
  static const delay = '延迟';
  static const testDelay = '测速';
  static const linesNotReady = '线路还没加载好，请稍候';

  static const planActive = '有效';
  static const planExpired = '已过期';
  static const planExhausted = '流量已用完';
  static const noPlan = '你还没有可用的套餐';
  static const buyPlan = '去购买';
  static const renew = '去续费';
  static const unlimited = '不限';
  static const neverExpires = '长期有效';
  static const switchPlan = '切换套餐';

  static String expiresOn(String date, int? days) =>
      days == null ? '到期 $date' : '到期 $date · 剩 $days 天';
  static String expiresSoon(int days) => days <= 0 ? '套餐今天到期' : '套餐 $days 天后到期';
  static const expiredTip = '套餐已过期，续费后即可继续使用';
  static const exhaustedTip = '本周期流量已用完';

  static const me = '我的';
  static const tutorial = '使用教程';
  static const support = '联系客服';
  static const orders = '订单与钱包';
  static const exportLogs = '导出日志';
  static const exportLogsDone = '日志已保存。联系客服时把这个文件发过去';
  static const exportLogsFailed = '导出日志失败，请稍后再试';
  static const logsHeading = '—— 日志（token、密码、订阅地址已打码）——';
  static const about = '关于';
  static const logout = '退出登录';
  static const logoutConfirm = '退出后会断开连接，并清除本机保存的登录信息。';
  static const cancel = '取消';
  static const confirm = '确定';
  static const refreshPlan = '刷新套餐和线路';
  static const advanced = '高级（FlClash 原版界面）';

  static const loginExpired = '登录已过期，请重新登录（连接不受影响）';
  static const relogin = '重新登录';
  static const syncFailed = '暂时无法更新线路，已使用上次的配置';
  static const syncing = '正在更新线路…';

  static const aboutBasedOn =
      '轻舟基于开源项目 FlClash（GPL-3.0）与 mihomo 内核（GPL-3.0）开发。';
  static const sourceCode = '源代码';
  static const version = '版本';

  static const registerTitle = '注册轻舟账号';
  static const registerLink = '没有账号？注册';
  static const register = '注册';
  static const code = '邮箱验证码';
  static const sendCode = '获取验证码';
  static String resendIn(int seconds) => '$seconds 秒后重发';
  static const codeSent = '验证码已发送，请查收邮件（也看看垃圾箱）';
  static const inviteOptional = '邀请码（选填）';
  static const passwordHint = '设置登录密码';
  static const registerFieldsRequired = '请填写邮箱、验证码和密码';
  static const emailFirst = '请先填写邮箱';

  static const choosePlan = '选择套餐';
  static const renewPlan = '续费';
  static const duration = '时长';
  static const payment = '支付方式';
  static const payBalance = '余额';
  static const payCrypto = 'USDT';
  static const payOnline = '支付宝 / 微信';
  static const total = '应付';
  static const discountSaved = '已优惠';
  static const fee = '手续费';
  static const pay = '去支付';
  static const noPlansForSale = '暂时没有可购买的套餐';
  static const noPaymentMethods = '暂时没有可用的支付方式';
  static const plansNeedLogin = '登录已过期，请重新登录后再购买';
  static const unlimitedTraffic = '不限流量';
  static String trafficPerCycle(String size) => '每月 $size';

  static const orderTitle = '订单支付';
  static const orderNo = '订单号';
  static const waitingPayment = '等待支付…';
  static const openCashier = '打开支付页面';
  static const openCashierHint = '将在浏览器中打开支付页面，付款完成后回到轻舟即可，这里会自动刷新。';
  static const paySuccess = '支付成功';
  static const paySuccessHint = '套餐已生效，线路正在更新。';
  static const backHome = '返回首页';
  static const orderClosed = '订单已关闭或已取消，请重新下单。';
  static const cryptoSendExactly = '请转账（金额须完全一致，含小数）';
  static String cryptoApprox(String currency, String fiat) =>
      '≈ ${currency == 'CNY' ? '¥' : '$currency '}$fiat';
  static const cryptoAddress = '收款地址';
  static String cryptoNetwork(String token, String network) =>
      '只能用 $network 网络转 $token，转错网络资金无法找回。';
  static const cryptoAmountWarn = '金额要和上面完全一致，不然无法自动到账。';
  static String timeLeft(String mmss) => '剩余时间 $mmss';
  static const paymentExpired = '支付已超时。如果已经转账但没到账，请带上交易哈希联系客服。';
  static const copy = '复制';
  static const copied = '已复制';
  static const qrPayHint = '用对应的 App 扫描二维码付款，或点下面的按钮打开。';

  static const modeTitle = '模式';
  static const modeSmart = '智能分流';
  static const modeGlobal = '全局代理';
  static const modeSmartHint = '推荐：国内网站直连，国外走轻舟';
  static const modeGlobalHint = '所有流量都走轻舟';

  static const location = '位置';
  static const locating = '检测中…';
  static const lineDown = '线路不通，换一条试试';
  static String sessionUsage(String used) => '本次 $used';

  static const connectFailed = '连接失败';
  static const connectFailedHint = '如果刚才拒绝了 VPN 授权，点「重试」后请选择「确定」。';
  static const retry = '重试';

  static const settings = '设置';
  static const splitTunnel = '分应用代理';
  static const splitEnable = '启用分应用代理';
  static const splitExclude = '选中的应用不走轻舟';
  static const splitExcludeHint = '适合银行、支付等国内应用（推荐）';
  static const splitInclude = '只有选中的应用走轻舟';
  static const splitIncludeHint = '其余应用都直连';
  static const splitPickChina = '一键选中国内应用';
  static const splitSearch = '搜索应用';
  static const splitNeedPermission = '需要允许轻舟读取应用列表，才能选择应用。';
  static const splitGrant = '去授权';
  static const splitLoading = '正在读取应用列表…';
  static String splitSelected(int count) => '已选 $count 个应用';
  static const splitShowSystem = '显示系统应用';

  static String networkError(LbNetworkIssue? issue) => switch (issue) {
    LbNetworkIssue.timeout => '连接服务器超时，请检查网络后重试',
    LbNetworkIssue.hostLookup => '找不到服务器地址，请检查网络或 DNS 设置',
    LbNetworkIssue.certificate => '服务器证书校验失败，请检查设备的日期和时间是否正确',
    _ => '网络连接失败，请检查网络后重试',
  };

  static String panelError(Object error, {String action = '操作'}) {
    if (error is! PanelException) return '$action失败，请稍后再试';
    if (error.isAuthExpired) return '登录已过期，请重新登录';
    return switch (error.code) {
      LbErrorCode.userExists || LbErrorCode.emailExists => '这个邮箱已经注册过了，请直接登录',
      LbErrorCode.registerClosed => '暂时关闭了注册，请稍后再试',
      LbErrorCode.inviteCodeInvalid => '邀请码不正确',
      LbErrorCode.verifyCodeInvalid => '验证码不正确或已过期',
      LbErrorCode.sendLimitReached => '今天发送验证码的次数太多了，明天再试',
      LbErrorCode.insufficientBalance => '余额不足，请换一种支付方式',
      LbErrorCode.planUnavailable => '这个套餐暂时不能购买',
      LbErrorCode.planOutOfStock => '这个套餐已售罄',
      LbErrorCode.rateLimited => '操作太频繁，请稍后再试',
      LbErrorCode.network => networkError(error.issue),
      LbErrorCode.captchaFailed => '安全验证没有通过，请重试',
      _ => '$action失败（${error.code}），请稍后再试',
    };
  }

  static String loginError(Object error) {
    if (error is! PanelException) return '登录失败，请稍后再试';
    return switch (error.code) {
      LbErrorCode.wrongPassword => '密码错误',
      LbErrorCode.userNotFound => '账号不存在',
      LbErrorCode.userDisabled => '账号已被停用，请联系客服',
      LbErrorCode.rateLimited => '操作太频繁，请稍后再试',
      LbErrorCode.network => networkError(error.issue),
      400 => '请求有误',
      _ => '登录失败（${error.code}），请稍后再试',
    };
  }
}
