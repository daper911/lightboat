import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/desktop/auth.dart';
import 'package:fl_clash/lightboat/desktop/payment.dart';
import 'package:fl_clash/lightboat/desktop/shell.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/logic/purchase.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LbDesktopPurchase extends ConsumerWidget {
  static const _summaryWidth = 280.0;

  final LbSubscription? renewing;

  const LbDesktopPurchase({super.key, this.renewing});

  Future<void> _order(
    BuildContext context,
    WidgetRef ref,
    LbPurchase purchase,
  ) async {
    final orderNo = await purchase.order();
    if (orderNo == null || !context.mounted) return;
    final paid = await showLbDesktopPayment(context, orderNo);
    if (paid) ref.read(lbDesktopNavProvider.notifier).go(LbDesktopTab.home);
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
    final Widget body;
    if (plans == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Column(
                  children: [
                    Text(
                      authExpired
                          ? LbStrings.plansNeedLogin
                          : LbStrings.panelError(error, action: '加载'),
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: authExpired
                          ? () => unawaited(showLbDesktopLogin(context))
                          : () => unawaited(purchase.load()),
                      child: Text(
                        authExpired ? LbStrings.relogin : LbStrings.retry,
                      ),
                    ),
                  ],
                ),
        ),
      );
    } else if (plans.isEmpty) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text(LbStrings.noPlansForSale)),
      );
    } else {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _Choices(state: state, purchase: purchase),
          ),
          const SizedBox(width: 24),
          SizedBox(
            width: _summaryWidth,
            child: _Summary(
              state: state,
              onPay: () => unawaited(_order(context, ref, purchase)),
            ),
          ),
        ],
      );
    }
    return LbDesktopPage(
      title: renewing != null ? LbStrings.renewPlan : LbStrings.buyPlanNav,
      children: [body],
    );
  }
}

class _Choices extends StatelessWidget {
  final LbPurchaseState state;
  final LbPurchase purchase;

  const _Choices({required this.state, required this.purchase});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final sectionStyle = context.textTheme.titleSmall?.copyWith(
      color: colors.muted,
    );
    final plan = state.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(LbStrings.choosePlan, style: sectionStyle),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in state.plans!)
              _PlanCard(
                plan: item,
                selected: item.id == plan?.id,
                onTap: () => purchase.selectPlan(item),
              ),
          ],
        ),
        if (plan != null) ...[
          const SizedBox(height: 24),
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
        const SizedBox(height: 10),
        if (state.methods.isEmpty)
          const Text(LbStrings.noPaymentMethods)
        else
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final method in state.methods)
                ChoiceChip(
                  label: Text(_methodLabel(method)),
                  selected: method.id == state.method?.id,
                  onSelected: (_) => purchase.selectMethod(method.id),
                ),
            ],
          ),
      ],
    );
  }

  static String _methodLabel(LbPaymentMethod method) {
    final title = switch (method.kind) {
      LbPaymentKind.balance => LbStrings.payBalance,
      LbPaymentKind.crypto => LbStrings.payCrypto,
      LbPaymentKind.online => LbStrings.payOnline,
    };
    return method.name.isEmpty || method.name == title
        ? title
        : '$title · ${method.name}';
  }
}

class _PlanCard extends StatelessWidget {
  static const _width = 240.0;

  final LbPlan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanCard({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    return SizedBox(
      width: _width,
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        shape: AppShape.lg.copyWith(
          side: BorderSide(
            color: selected ? colors.accent : colors.rule,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: AppShape.lg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                const SizedBox(height: 6),
                Text(
                  plan.traffic > 0
                      ? LbStrings.trafficPerCycle(lbFormatBytes(plan.traffic))
                      : LbStrings.unlimitedTraffic,
                  style: textTheme.bodyMedium?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 14),
                Text(
                  '${lbFormatCents(plan.unitPrice)} / ${plan.durationLabel(1)}',
                  style: textTheme.titleMedium?.copyWith(
                    color: colors.accent,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final LbPurchaseState state;
  final VoidCallback onPay;

  const _Summary({required this.state, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final plan = state.plan;
    final quote = state.quote;
    final error = state.error;
    Widget row(String label, String value, {bool emphasize = false}) {
      final style = emphasize
          ? textTheme.titleLarge?.copyWith(
              color: colors.ink,
              fontWeight: FontWeight.bold,
            )
          : textTheme.bodyMedium?.copyWith(color: colors.muted);
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

    return LbCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (plan != null) ...[
            Text(
              plan.name,
              style: textTheme.titleMedium?.copyWith(
                color: colors.ink,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              plan.durationLabel(state.quantity),
              style: textTheme.bodyMedium?.copyWith(color: colors.muted),
            ),
            const SizedBox(height: 12),
            Divider(color: colors.rule),
          ],
          if (quote != null) ...[
            if (quote.discount > 0)
              row(LbStrings.discountSaved, '-${lbFormatCents(quote.discount)}'),
            if (quote.fee > 0) row(LbStrings.fee, lbFormatCents(quote.fee)),
            row(LbStrings.total, lbFormatCents(quote.amount), emphasize: true),
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
          const SizedBox(height: 16),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: state.canOrder ? onPay : null,
              child: const Text(LbStrings.pay),
            ),
          ),
        ],
      ),
    );
  }
}
