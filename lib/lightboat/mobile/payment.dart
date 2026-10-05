import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/logic/purchase.dart';
import 'package:fl_clash/lightboat/widgets/crypto_payment.dart';
import 'package:fl_clash/lightboat/widgets/qr.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LbPaymentPage extends ConsumerWidget {
  final String orderNo;

  const LbPaymentPage({super.key, required this.orderNo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final provider = lbPaymentProvider(orderNo);
    final state = ref.watch(provider);
    final order = state.order;
    final error = state.error;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: const Text(LbStrings.orderTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (order != null) _OrderSummary(order: order),
          const SizedBox(height: 24),
          if (state.paid)
            const _PaidBlock()
          else if (state.closed)
            _Notice(text: LbStrings.orderClosed, color: colors.seal)
          else
            _buildPending(context, colors, state.checkout),
          if (error != null) ...[
            const SizedBox(height: 16),
            _Notice(
              text: LbStrings.panelError(error, action: '支付'),
              color: colors.seal,
            ),
            Center(
              child: TextButton(
                onPressed: () =>
                    unawaited(ref.read(provider.notifier).refresh()),
                child: const Text(LbStrings.retry),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPending(
    BuildContext context,
    LbColors colors,
    LbCheckout? checkout,
  ) {
    if (checkout == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final crypto = checkout.crypto;
    if (checkout.type == 'crypto' && crypto != null) {
      return LbCryptoPaymentView(crypto: crypto);
    }
    final url = checkout.checkoutUrl;
    return Column(
      children: [
        if (checkout.type == 'qr' && url.isNotEmpty) ...[
          LbQrCode(data: url),
          const SizedBox(height: 12),
          _Notice(text: LbStrings.qrPayHint, color: colors.muted),
        ] else
          _Notice(text: LbStrings.openCashierHint, color: colors.muted),
        const SizedBox(height: 16),
        if (url.isNotEmpty)
          SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent,
                foregroundColor: colors.accentInk,
              ),
              onPressed: () => unawaited(lbOpenUrl(url)),
              child: const Text(LbStrings.openCashier),
            ),
          ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(
              LbStrings.waitingPayment,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.muted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final LbOrder order;

  const _OrderSummary({required this.order});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          order.planName.isEmpty ? LbStrings.orderTitle : order.planName,
          style: textTheme.titleLarge?.copyWith(
            color: colors.ink,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${LbStrings.total} ${lbFormatCents(order.amount)}'
          '${order.paymentName.isEmpty ? '' : ' · ${order.paymentName}'}',
          style: textTheme.titleMedium?.copyWith(color: colors.accent),
        ),
        const SizedBox(height: 4),
        Text(
          '${LbStrings.orderNo} ${order.orderNo}',
          style: textTheme.bodySmall?.copyWith(color: colors.muted),
        ),
      ],
    );
  }
}

class _PaidBlock extends StatelessWidget {
  const _PaidBlock();

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return Column(
      children: [
        Text(
          LbStrings.paySuccess,
          style: context.textTheme.headlineSmall?.copyWith(
            color: colors.accent,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        _Notice(text: LbStrings.paySuccessHint, color: colors.muted),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.accent,
            foregroundColor: colors.accentInk,
          ),
          onPressed: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text(LbStrings.backHome),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  final String text;
  final Color color;

  const _Notice({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: context.textTheme.bodyMedium?.copyWith(color: color),
    );
  }
}
