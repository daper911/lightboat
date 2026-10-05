import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/api/commerce.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/qr.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

class LbCryptoPaymentView extends StatefulWidget {
  final LbCryptoPayment crypto;

  const LbCryptoPaymentView({super.key, required this.crypto});

  @override
  State<LbCryptoPaymentView> createState() => _LbCryptoPaymentViewState();
}

class _LbCryptoPaymentViewState extends State<LbCryptoPaymentView> {
  Timer? _ticker;
  String? _copied;

  int get _secondsLeft {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return (widget.crypto.expiresAt - now).clamp(0, 1 << 31);
  }

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _copy(String key, String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) setState(() => _copied = key);
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final crypto = widget.crypto;
    final left = _secondsLeft;
    if (left <= 0) {
      return Text(
        LbStrings.paymentExpired,
        textAlign: TextAlign.center,
        style: textTheme.bodyMedium?.copyWith(color: colors.seal),
      );
    }
    final mmss =
        '${(left ~/ 60).toString().padLeft(2, '0')}:'
        '${(left % 60).toString().padLeft(2, '0')}';
    const tabular = [FontFeature.tabularFigures()];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LbStrings.cryptoSendExactly,
          style: textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: crypto.amount,
                      style: textTheme.headlineMedium?.copyWith(
                        color: colors.ink,
                        fontWeight: FontWeight.bold,
                        fontFeatures: tabular,
                      ),
                    ),
                    TextSpan(
                      text: ' ${crypto.token}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => unawaited(_copy('amount', crypto.amount)),
              child: Text(
                _copied == 'amount' ? LbStrings.copied : LbStrings.copy,
              ),
            ),
          ],
        ),
        Text(
          LbStrings.cryptoApprox(crypto.currency, crypto.fiat),
          style: textTheme.bodySmall?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.accentSoft,
                shape: AppShape.full,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                child: Text(
                  crypto.networkLabel,
                  style: textTheme.labelLarge?.copyWith(color: colors.accent),
                ),
              ),
            ),
            Text(
              LbStrings.timeLeft(mmss),
              style: textTheme.bodyMedium?.copyWith(
                color: left < 120 ? colors.seal : colors.muted,
                fontFeatures: tabular,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Center(child: LbQrCode(data: crypto.address, size: 180)),
        const SizedBox(height: 16),
        Text(
          LbStrings.cryptoAddress,
          style: textTheme.bodyMedium?.copyWith(color: colors.muted),
        ),
        const SizedBox(height: 4),
        SelectableText(
          crypto.address,
          style: textTheme.bodyMedium?.copyWith(
            color: colors.ink,
            fontFamily: 'JetBrainsMono',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: OutlinedButton(
            onPressed: () => unawaited(_copy('address', crypto.address)),
            child: Text(
              _copied == 'address' ? LbStrings.copied : LbStrings.copy,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '· ${LbStrings.cryptoAmountWarn}\n'
          '· ${LbStrings.cryptoNetwork(crypto.token, crypto.networkLabel)}',
          style: textTheme.bodyMedium?.copyWith(color: colors.seal),
        ),
      ],
    );
  }
}
