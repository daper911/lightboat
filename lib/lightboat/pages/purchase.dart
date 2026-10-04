import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/pages/home.dart';
import 'package:fl_clash/lightboat/pages/login.dart';
import 'package:fl_clash/lightboat/pages/payment.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Buys a plan, or renews [renewing] when it is given and still on sale.
Future<void> showLbPurchase(BuildContext context, {LbSubscription? renewing}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => LbPurchasePage(renewing: renewing)),
  );
}

class LbPurchasePage extends ConsumerStatefulWidget {
  final LbSubscription? renewing;

  const LbPurchasePage({super.key, this.renewing});

  @override
  ConsumerState<LbPurchasePage> createState() => _LbPurchasePageState();
}

class _LbPurchasePageState extends ConsumerState<LbPurchasePage> {
  List<LbPlan>? _plans;
  List<LbPaymentMethod> _methods = const [];
  LbPlan? _plan;
  int _quantity = 1;
  LbPaymentMethod? _method;
  LbQuote? _quote;
  int _quoteRequest = 0;
  bool _ordering = false;
  Object? _error;

  LbSession get _session => ref.read(lbSessionProvider.notifier);

  /// Renewal only works while the subscription's own plan is still listed.
  LbSubscription? get _renewing {
    final renewing = widget.renewing;
    if (renewing == null || _plan?.id != renewing.planId) return null;
    return renewing;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final (plans, methods) = await _session.authed(
        (api, jwt) async =>
            (await api.plans(jwt), await api.paymentMethods(jwt)),
      );
      if (!mounted) return;
      final plan =
          plans.firstWhereOrNull(
            (item) => item.id == widget.renewing?.planId,
          ) ??
          plans.firstOrNull;
      setState(() {
        _plans = plans;
        _methods = methods;
        _method =
            methods.firstWhereOrNull(
              (item) => item.kind == LbPaymentKind.online,
            ) ??
            methods.firstOrNull;
      });
      if (plan != null) _selectPlan(plan);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _selectPlan(LbPlan plan) {
    setState(() {
      _plan = plan;
      _quantity = plan.durations.first.quantity;
    });
    unawaited(_requote());
  }

  Future<void> _requote() async {
    final plan = _plan;
    final method = _method;
    if (plan == null || method == null) return;
    final request = ++_quoteRequest;
    setState(() => _quote = null);
    try {
      final quote = await _session.authed(
        (api, jwt) => api.quote(
          jwt,
          planId: plan.id,
          quantity: _quantity,
          payment: method.id,
          userSubscribeId: _renewing?.id,
        ),
      );
      if (mounted && request == _quoteRequest) setState(() => _quote = quote);
    } catch (error) {
      if (mounted && request == _quoteRequest) setState(() => _error = error);
    }
  }

  Future<void> _order() async {
    final plan = _plan;
    final method = _method;
    if (plan == null || method == null) return;
    setState(() {
      _ordering = true;
      _error = null;
    });
    try {
      final renewing = _renewing;
      final orderNo = await _session.authed(
        (api, jwt) => renewing != null
            ? api.renew(
                jwt,
                userSubscribeId: renewing.id,
                quantity: _quantity,
                payment: method.id,
              )
            : api.purchase(
                jwt,
                planId: plan.id,
                quantity: _quantity,
                payment: method.id,
              ),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => LbPaymentPage(orderNo: orderNo),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final plans = _plans;
    final error = _error;
    final authExpired = error is PanelException && error.isAuthExpired;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.renewing != null ? LbStrings.renewPlan : LbStrings.choosePlan,
        ),
      ),
      body: plans == null
          ? Center(
              child: error == null
                  ? const CircularProgressIndicator()
                  : _ErrorBlock(
                      message: authExpired
                          ? LbStrings.plansNeedLogin
                          : LbStrings.panelError(error, action: '加载'),
                      actionLabel: authExpired
                          ? LbStrings.relogin
                          : LbStrings.retry,
                      onAction: authExpired
                          ? () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LbLoginPage(),
                              ),
                            )
                          : () => unawaited(_load()),
                    ),
            )
          : plans.isEmpty
          ? const Center(child: Text(LbStrings.noPlansForSale))
          : _buildForm(context, colors, plans),
    );
  }

  Widget _buildForm(BuildContext context, LbColors colors, List<LbPlan> plans) {
    final textTheme = context.textTheme;
    final plan = _plan;
    final quote = _quote;
    final error = _error;
    final sectionStyle = textTheme.titleSmall?.copyWith(color: colors.muted);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        for (final item in plans) ...[
          _PlanTile(
            plan: item,
            selected: item.id == plan?.id,
            onTap: () => _selectPlan(item),
          ),
          const SizedBox(height: 10),
        ],
        if (plan != null) ...[
          const SizedBox(height: 14),
          Text(LbStrings.duration, style: sectionStyle),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final duration in plan.durations)
                ChoiceChip(
                  label: Text(
                    duration.discount < 100
                        ? '${plan.durationLabel(duration.quantity)} · '
                              '${(duration.discount / 10).toStringAsFixed(duration.discount % 10 == 0 ? 0 : 1)} 折'
                        : plan.durationLabel(duration.quantity),
                  ),
                  selected: duration.quantity == _quantity,
                  onSelected: (_) {
                    setState(() => _quantity = duration.quantity);
                    unawaited(_requote());
                  },
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(LbStrings.payment, style: sectionStyle),
        const SizedBox(height: 4),
        if (_methods.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(LbStrings.noPaymentMethods),
          ),
        RadioGroup<int>(
          groupValue: _method?.id,
          onChanged: (id) {
            setState(() => _method = _methods.firstWhere((m) => m.id == id));
            unawaited(_requote());
          },
          child: Column(
            children: [
              for (final method in _methods) _PaymentTile(method: method),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Divider(color: colors.rule),
        const SizedBox(height: 8),
        if (quote != null) ...[
          if (quote.discount > 0)
            _AmountRow(
              label: LbStrings.discountSaved,
              value: '-${lbFormatCents(quote.discount)}',
            ),
          if (quote.fee > 0)
            _AmountRow(label: LbStrings.fee, value: lbFormatCents(quote.fee)),
          _AmountRow(
            label: LbStrings.total,
            value: lbFormatCents(quote.amount),
            emphasize: true,
          ),
        ] else if (error == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            LbStrings.panelError(error, action: '下单'),
            style: textTheme.bodyMedium?.copyWith(color: colors.seal),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: colors.accentInk,
            ),
            onPressed: quote == null || _ordering || _method == null
                ? null
                : () => unawaited(_order()),
            child: const Text(LbStrings.pay),
          ),
        ),
      ],
    );
  }
}

class _PlanTile extends StatelessWidget {
  final LbPlan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    return Material(
      color: selected ? colors.accentSoft : Colors.transparent,
      shape: AppShape.xl.copyWith(
        side: BorderSide(color: selected ? colors.accent : colors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: AppShape.xl,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plan.name,
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.traffic > 0
                          ? LbStrings.trafficPerCycle(
                              lbFormatBytes(plan.traffic),
                            )
                          : LbStrings.unlimitedTraffic,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${lbFormatCents(plan.unitPrice)} / ${plan.durationLabel(1)}',
                style: textTheme.titleSmall?.copyWith(
                  color: colors.accent,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                GlyphIcon(AppGlyphs.checkCircle, color: colors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final LbPaymentMethod method;

  const _PaymentTile({required this.method});

  @override
  Widget build(BuildContext context) {
    final title = switch (method.kind) {
      LbPaymentKind.balance => LbStrings.payBalance,
      LbPaymentKind.crypto => LbStrings.payCrypto,
      LbPaymentKind.online => LbStrings.payOnline,
    };
    return RadioListTile<int>(
      value: method.id,
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: method.name.isEmpty || method.name == title
          ? null
          : Text(method.name),
    );
  }
}

class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final style = emphasize
        ? context.textTheme.titleLarge?.copyWith(
            color: colors.ink,
            fontWeight: FontWeight.bold,
          )
        : context.textTheme.bodyMedium?.copyWith(color: colors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: style?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _ErrorBlock({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.textTheme.bodyLarge?.copyWith(color: colors.ink),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}
