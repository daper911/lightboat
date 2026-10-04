import 'dart:convert';

import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';

final pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class FakePanelApi extends PanelApi {
  FakePanelApi() : super(userAgent: 'test');

  final List<String?> loginTickets = [];
  final List<int> verifiedX = [];
  int captchasServed = 0;
  bool requireCaptcha = false;
  bool rejectFirstCaptcha = false;
  int? loginError;

  @override
  Future<String> login({
    required String email,
    required String password,
    String? captchaTicket,
  }) async {
    loginTickets.add(captchaTicket);
    final error = loginError;
    if (error != null) throw PanelException(error, '');
    if (requireCaptcha && captchaTicket == null) {
      throw const PanelException(LbErrorCode.captchaRequired, '');
    }
    return 'jwt';
  }

  List<LbAnnouncement> announcementList = const [];

  @override
  Future<List<LbAnnouncement>> announcements(String jwt) async =>
      announcementList;

  List<LbSubscription> subscriptionList = const [];
  int? subscriptionsError;

  @override
  Future<List<LbSubscription>> subscriptions(String jwt) async {
    final error = subscriptionsError;
    if (error != null) throw PanelException(error, '');
    return subscriptionList;
  }

  @override
  Future<LbSiteConfig> siteConfig() async => const LbSiteConfig();

  @override
  Future<LbSlideCaptcha> slideCaptcha() async {
    captchasServed++;
    return LbSlideCaptcha(
      id: 'captcha-$captchasServed',
      image: pixel,
      thumb: pixel,
      thumbX: 5,
      thumbY: 72,
      thumbWidth: 65,
      thumbHeight: 65,
    );
  }

  @override
  Future<String> verifySlideCaptcha({
    required String id,
    required int x,
    required int y,
  }) async {
    verifiedX.add(x);
    if (rejectFirstCaptcha && verifiedX.length == 1) {
      throw const PanelException(LbErrorCode.captchaFailed, '');
    }
    return 'ticket';
  }

  final List<String> codesSent = [];
  final List<String?> registerTickets = [];
  final List<String> ordered = [];
  int? registerError;
  List<LbPlan> planList = const [];
  List<LbPaymentMethod> methods = const [];
  LbCheckout checkoutResult = const LbCheckout(type: 'url', checkoutUrl: '');
  LbOrderStatus orderStatus = LbOrderStatus.pending;

  @override
  Future<void> sendEmailCode({
    required String email,
    required String captchaTicket,
  }) async {
    codesSent.add('$email/$captchaTicket');
  }

  @override
  Future<String> register({
    required String email,
    required String password,
    required String code,
    String? invite,
    String? captchaTicket,
  }) async {
    registerTickets.add(captchaTicket);
    final error = registerError;
    if (error != null) throw PanelException(error, '');
    return 'jwt';
  }

  @override
  Future<List<LbPlan>> plans(String jwt) async => planList;

  @override
  Future<List<LbPaymentMethod>> paymentMethods(String jwt) async => methods;

  @override
  Future<LbQuote> quote(
    String jwt, {
    required int planId,
    required int quantity,
    required int payment,
    int? userSubscribeId,
  }) async => LbQuote(
    amount: 1000 * quantity,
    price: 1000 * quantity,
    discount: 0,
    fee: 0,
    giftAmount: 0,
  );

  @override
  Future<String> purchase(
    String jwt, {
    required int planId,
    required int quantity,
    required int payment,
  }) async {
    ordered.add('purchase $planId x$quantity via $payment');
    return 'order-1';
  }

  @override
  Future<String> renew(
    String jwt, {
    required int userSubscribeId,
    required int quantity,
    required int payment,
  }) async {
    ordered.add('renew $userSubscribeId x$quantity via $payment');
    return 'order-1';
  }

  @override
  Future<LbOrder> order(String jwt, String orderNo) async => LbOrder(
    orderNo: orderNo,
    status: orderStatus,
    amount: 1000,
    createdAt: 0,
    paymentName: 'pay',
    planName: '基础版',
    quantity: 1,
  );

  @override
  Future<LbCheckout> checkout(
    String jwt, {
    required String orderNo,
    required String returnUrl,
  }) async => checkoutResult;
}

class MemoryStore extends LbCredentialStore {
  LbStoredSession saved = const LbStoredSession();

  @override
  Future<LbStoredSession> load() async => saved;

  @override
  Future<void> save(LbStoredSession session) async => saved = session;

  @override
  Future<void> clearJwt() async => saved = LbStoredSession(
    email: saved.email,
    subscription: saved.subscription,
    subscriptions: saved.subscriptions,
  );

  @override
  Future<void> clear() async => saved = const LbStoredSession();
}
