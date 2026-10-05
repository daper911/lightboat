import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/logic/purchase.dart';
import 'package:fl_clash/lightboat/mobile/login.dart';
import 'package:fl_clash/lightboat/mobile/payment.dart';
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

class LbPurchasePage extends ConsumerWidget {
  final LbSubscription? renewing;

  const LbPurchasePage({super.key, this.renewing});

  Future<void> _order(BuildContext context, LbPurchase purchase) async {
    final orderNo = await purchase.order();
    if (orderNo == null || !context.mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => LbPaymentPage(orderNo: orderNo)),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final provider = lbPurchaseProvider(renewing);
    final state = ref.watch(provider);
    final purchase = ref.read(provider.notifier);
    final plans = state.plans;
    final error = state.error;
    final authExpired = error is PanelException && error.isAuthExpired;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: Text(
          renewing != null ? LbStrings.renewPlan : LbStrings.choosePlan,
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
                          : () => unawaited(purchase.load()),
                    ),
            )
          : plans.isEmpty
          ? const Center(child: Text(LbStrings.noPlansForSale))
          : _buildForm(context, colors, state, purchase),
    );
  }

  Widget _buildForm(
    BuildContext context,
    LbColors colors,
    LbPurchaseState state,
    LbPurchase purchase,
  ) {
    final textTheme = context.textTheme;
    final plan = state.plan;
    final quote = state.quote;
    final error = state.error;
    final sectionStyle = textTheme.titleSmall?.copyWith(color: colors.muted);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        for (final item in state.plans!) ...[
          _PlanTile(
            plan: item,
            selected: item.id == plan?.id,
            onTap: () => purchase.selectPlan(item),
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
                  label: Text(plan.durationChoiceLabel(duration)),
                  selected: duration.quantity == state.quantity,
                  onSelected: (_) => purchase.selectQuantity(duration.quantity),
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Text(LbStrings.payment, style: sectionStyle),
        const SizedBox(height: 4),
        if (state.methods.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(LbStrings.noPaymentMethods),
          ),
        RadioGroup<int>(
          groupValue: state.method?.id,
          onChanged: (id) {
            if (id != null) purchase.selectMethod(id);
          },
          child: Column(
            children: [
              for (final method in state.methods) _PaymentTile(method: method),
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
            onPressed: state.canOrder
                ? () => unawaited(_order(context, purchase))
                : null,
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
