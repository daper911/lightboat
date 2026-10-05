import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LbPurchaseState {
  final List<LbPlan>? plans;
  final List<LbPaymentMethod> methods;
  final LbPlan? plan;
  final int quantity;
  final LbPaymentMethod? method;
  final LbQuote? quote;
  final bool ordering;
  final Object? error;

  const LbPurchaseState({
    this.plans,
    this.methods = const [],
    this.plan,
    this.quantity = 1,
    this.method,
    this.quote,
    this.ordering = false,
    this.error,
  });

  bool get canOrder => quote != null && !ordering && method != null;

  LbPurchaseState copyWith({
    List<LbPlan>? plans,
    List<LbPaymentMethod>? methods,
    LbPlan? plan,
    int? quantity,
    LbPaymentMethod? method,
    LbQuote? quote,
    bool clearQuote = false,
    bool? ordering,
    Object? error,
    bool clearError = false,
  }) => LbPurchaseState(
    plans: plans ?? this.plans,
    methods: methods ?? this.methods,
    plan: plan ?? this.plan,
    quantity: quantity ?? this.quantity,
    method: method ?? this.method,
    quote: clearQuote ? null : quote ?? this.quote,
    ordering: ordering ?? this.ordering,
    error: clearError ? null : error ?? this.error,
  );
}

/// Buys a plan, or renews the given subscription while its plan is on sale.
final lbPurchaseProvider = NotifierProvider.autoDispose
    .family<LbPurchase, LbPurchaseState, LbSubscription?>(LbPurchase.new);

class LbPurchase extends Notifier<LbPurchaseState> {
  final LbSubscription? renewing;
  int _quoteRequest = 0;

  LbPurchase(this.renewing);

  LbSession get _session => ref.read(lbSessionProvider.notifier);

  LbSubscription? get _renewal {
    final subscription = renewing;
    if (subscription == null || state.plan?.id != subscription.planId) {
      return null;
    }
    return subscription;
  }

  @override
  LbPurchaseState build() {
    unawaited(Future.microtask(load));
    return const LbPurchaseState();
  }

  Future<void> load() async {
    state = state.copyWith(clearError: true);
    try {
      final (plans, methods) = await _session.authed(
        (api, jwt) async =>
            (await api.plans(jwt), await api.paymentMethods(jwt)),
      );
      if (!ref.mounted) return;
      state = state.copyWith(
        plans: plans,
        methods: methods,
        method:
            methods.firstWhereOrNull(
              (item) => item.kind == LbPaymentKind.online,
            ) ??
            methods.firstOrNull,
      );
      final plan =
          plans.firstWhereOrNull((item) => item.id == renewing?.planId) ??
          plans.firstOrNull;
      if (plan != null) selectPlan(plan);
    } catch (error) {
      if (ref.mounted) state = state.copyWith(error: error);
    }
  }

  void selectPlan(LbPlan plan) {
    state = state.copyWith(plan: plan, quantity: plan.durations.first.quantity);
    unawaited(_requote());
  }

  void selectQuantity(int quantity) {
    state = state.copyWith(quantity: quantity);
    unawaited(_requote());
  }

  void selectMethod(int id) {
    state = state.copyWith(
      method: state.methods.firstWhere((method) => method.id == id),
    );
    unawaited(_requote());
  }

  Future<void> _requote() async {
    final plan = state.plan;
    final method = state.method;
    if (plan == null || method == null) return;
    final request = ++_quoteRequest;
    state = state.copyWith(clearQuote: true);
    try {
      final quote = await _session.authed(
        (api, jwt) => api.quote(
          jwt,
          planId: plan.id,
          quantity: state.quantity,
          payment: method.id,
          userSubscribeId: _renewal?.id,
        ),
      );
      if (ref.mounted && request == _quoteRequest) {
        state = state.copyWith(quote: quote);
      }
    } catch (error) {
      if (ref.mounted && request == _quoteRequest) {
        state = state.copyWith(error: error);
      }
    }
  }

  /// The new order's number, or null when ordering failed and [state] says why.
  Future<String?> order() async {
    final plan = state.plan;
    final method = state.method;
    if (plan == null || method == null) return null;
    state = state.copyWith(ordering: true, clearError: true);
    try {
      final renewal = _renewal;
      final quantity = state.quantity;
      return await _session.authed(
        (api, jwt) => renewal != null
            ? api.renew(
                jwt,
                userSubscribeId: renewal.id,
                quantity: quantity,
                payment: method.id,
              )
            : api.purchase(
                jwt,
                planId: plan.id,
                quantity: quantity,
                payment: method.id,
              ),
      );
    } catch (error) {
      if (ref.mounted) state = state.copyWith(error: error);
      return null;
    } finally {
      if (ref.mounted) state = state.copyWith(ordering: false);
    }
  }
}

class LbPaymentState {
  final LbOrder? order;
  final LbCheckout? checkout;
  final Object? error;

  const LbPaymentState({this.order, this.checkout, this.error});

  bool get paid => order?.isPaid ?? false;

  bool get closed => order?.isOver ?? false;
}

/// Follows an order until it is paid or closed, opening the cashier in the
/// browser when the payment method has one.
final lbPaymentProvider = NotifierProvider.autoDispose
    .family<LbPayment, LbPaymentState, String>(LbPayment.new);

class LbPayment extends Notifier<LbPaymentState> {
  /// Same cadence as the website's order page.
  static const _pollEvery = Duration(seconds: 3);

  final String orderNo;
  Timer? _poll;
  bool _checkingOut = false;

  LbPayment(this.orderNo);

  LbSession get _session => ref.read(lbSessionProvider.notifier);

  @override
  LbPaymentState build() {
    unawaited(Future.microtask(refresh));
    _poll = Timer.periodic(_pollEvery, (_) => unawaited(refresh()));
    ref.onDispose(() => _poll?.cancel());
    return const LbPaymentState();
  }

  Future<void> refresh() async {
    try {
      final order = await _session.authed(
        (api, jwt) => api.order(jwt, orderNo),
      );
      if (!ref.mounted) return;
      state = LbPaymentState(order: order, checkout: state.checkout);
      if (order.isPaid || order.isOver) {
        _poll?.cancel();
        if (order.isPaid) unawaited(_session.refresh());
        return;
      }
      if (state.checkout == null && !_checkingOut) await _startCheckout();
    } catch (error) {
      if (ref.mounted) {
        state = LbPaymentState(
          order: state.order,
          checkout: state.checkout,
          error: error,
        );
      }
    }
  }

  Future<void> _startCheckout() async {
    _checkingOut = true;
    try {
      final checkout = await _session.authed(
        (api, jwt) => api.checkout(
          jwt,
          orderNo: orderNo,
          returnUrl: LbConfig.siteLink('order'),
        ),
      );
      if (!ref.mounted) return;
      state = LbPaymentState(order: state.order, checkout: checkout);
      if (checkout.type == 'url' && checkout.checkoutUrl.isNotEmpty) {
        unawaited(lbOpenUrl(checkout.checkoutUrl));
      }
    } finally {
      _checkingOut = false;
    }
  }
}
