import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/logic/purchase.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/crypto_payment.dart';
import 'package:fl_clash/lightboat/widgets/qr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// True when the order was paid before the dialog closed.
Future<bool> showLbDesktopPayment(BuildContext context, String orderNo) async {
  final paid = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaymentDialog(orderNo: orderNo),
  );
  return paid ?? false;
}

class _PaymentDialog extends ConsumerWidget {
  static const _width = 440.0;

  final String orderNo;

  const _PaymentDialog({required this.orderNo});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final provider = lbPaymentProvider(orderNo);
    final state = ref.watch(provider);
    final order = state.order;
    final error = state.error;
    final Widget body;
    if (state.paid) {
      body = Column(
        children: [
          Text(
            LbStrings.paySuccess,
            style: textTheme.headlineSmall?.copyWith(
              color: colors.accent,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            LbStrings.paySuccessHint,
            style: textTheme.bodyMedium?.copyWith(color: colors.muted),
          ),
        ],
      );
    } else if (state.closed) {
      body = Text(
        LbStrings.orderClosed,
        style: textTheme.bodyMedium?.copyWith(color: colors.seal),
      );
    } else {
      body = _Pending(checkout: state.checkout);
    }
    return AlertDialog(
      title: Text(
        order == null || order.planName.isEmpty
            ? LbStrings.orderTitle
            : order.planName,
      ),
      content: SizedBox(
        width: _width,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (order != null) ...[
                Text(
                  '${LbStrings.total} ${lbFormatCents(order.amount)}'
                  '${order.paymentName.isEmpty ? '' : ' · ${order.paymentName}'}',
                  style: textTheme.titleMedium?.copyWith(color: colors.accent),
                ),
                const SizedBox(height: 2),
                Text(
                  '${LbStrings.orderNo} ${order.orderNo}',
                  style: textTheme.bodySmall?.copyWith(color: colors.muted),
                ),
                const SizedBox(height: 20),
              ],
              body,
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  LbStrings.panelError(error, action: '支付'),
                  style: textTheme.bodyMedium?.copyWith(color: colors.seal),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (error != null)
          TextButton(
            onPressed: () => unawaited(ref.read(provider.notifier).refresh()),
            child: const Text(LbStrings.retry),
          ),
        state.paid
            ? FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(LbStrings.backHome),
              )
            : TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(LbStrings.close),
              ),
      ],
    );
  }
}

class _Pending extends StatelessWidget {
  final LbCheckout? checkout;

  const _Pending({required this.checkout});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final checkout = this.checkout;
    if (checkout == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final crypto = checkout.crypto;
    if (checkout.type == 'crypto' && crypto != null) {
      return LbCryptoPaymentView(crypto: crypto);
    }
    final url = checkout.checkoutUrl;
    final hintStyle = textTheme.bodyMedium?.copyWith(color: colors.muted);
    return Column(
      children: [
        if (checkout.type == 'qr' && url.isNotEmpty) ...[
          LbQrCode(data: url),
          const SizedBox(height: 12),
          Text(LbStrings.qrPayHint, style: hintStyle),
        ] else
          Text(LbStrings.openCashierHint, style: hintStyle),
        const SizedBox(height: 16),
        if (url.isNotEmpty)
          FilledButton(
            onPressed: () => unawaited(lbOpenUrl(url)),
            child: const Text(LbStrings.openCashier),
          ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Text(LbStrings.waitingPayment, style: hintStyle),
          ],
        ),
      ],
    );
  }
}
