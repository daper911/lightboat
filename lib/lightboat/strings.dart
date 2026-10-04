import 'package:fl_clash/lightboat/api/panel_api.dart';

/// Lightboat's own copy, kept out of FlClash's ARB files so upstream merges
/// never conflict on them. Chinese only until English lands (P1).
abstract final class LbStrings {
  static const appName = '轻舟';
  static const slogan = '轻舟已过万重山';

  static const email = '邮箱';
  static const password = '密码';
  static const login = '登录';
  static const register = '没有账号？去官网注册';
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

  static String loginError(Object error) {
    if (error is! PanelException) return '登录失败，请稍后再试';
    return switch (error.code) {
      LbErrorCode.wrongPassword => '密码错误',
      LbErrorCode.userNotFound => '账号不存在',
      LbErrorCode.userDisabled => '账号已被停用，请联系客服',
      LbErrorCode.rateLimited => '操作太频繁，请稍后再试',
      LbErrorCode.network => '网络连接失败，请检查网络后重试',
      400 => '请求有误',
      _ => '登录失败（${error.code}），请稍后再试',
    };
  }
}
