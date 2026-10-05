import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Resolves to the panel's one-shot ticket, or null when the user gives up.
Future<String?> showSlideCaptcha(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _SlideCaptchaDialog(),
  );
}

class _SlideCaptchaDialog extends ConsumerStatefulWidget {
  const _SlideCaptchaDialog();

  @override
  ConsumerState<_SlideCaptchaDialog> createState() =>
      _SlideCaptchaDialogState();
}

class _SlideCaptchaDialogState extends ConsumerState<_SlideCaptchaDialog> {
  static const _knobWidth = 56.0;
  static const _trackHeight = 48.0;

  /// The panel rejects answers given sooner than this after the image loads.
  static const _minAnswerTime = Duration(milliseconds: 450);

  LbSlideCaptcha? _captcha;
  DateTime? _loadedAt;
  double _offset = 0;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load({String? message}) async {
    setState(() {
      _busy = true;
      _captcha = null;
      _offset = 0;
      _message = message;
    });
    try {
      final captcha = await ref.read(lbPanelApiProvider).slideCaptcha();
      if (!mounted) return;
      setState(() {
        _captcha = captcha;
        _loadedAt = DateTime.now();
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = error is PanelException
            ? LbStrings.loginError(error)
            : LbStrings.captchaLoadFailed;
      });
    }
  }

  Future<void> _submit(double trackWidth) async {
    final captcha = _captcha;
    if (captcha == null || _busy) return;
    setState(() => _busy = true);
    final elapsed = DateTime.now().difference(_loadedAt ?? DateTime.now());
    if (elapsed < _minAnswerTime) {
      await Future<void>.delayed(_minAnswerTime - elapsed);
    }
    final x = captcha.pieceX(_offset, trackWidth, _knobWidth).round();
    try {
      final ticket = await ref
          .read(lbPanelApiProvider)
          .verifySlideCaptcha(id: captcha.id, x: x, y: captcha.thumbY);
      if (mounted) Navigator.of(context).pop(ticket);
    } on PanelException catch (error) {
      if (!mounted) return;
      await _load(
        message: error.code == LbErrorCode.captchaFailed
            ? LbStrings.captchaFailed
            : LbStrings.loginError(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return AlertDialog(
      title: const Text(LbStrings.captchaTitle),
      content: SizedBox(
        width: 300,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _message ?? LbStrings.captchaHint,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: _message == null ? colors.muted : colors.seal,
                  ),
                ),
                const SizedBox(height: 12),
                _buildPuzzle(width),
                const SizedBox(height: 12),
                _buildTrack(width, colors),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => unawaited(_load()),
          child: const Text(LbStrings.captchaRefresh),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(LbStrings.cancel),
        ),
      ],
    );
  }

  Widget _buildPuzzle(double width) {
    final captcha = _captcha;
    final scale = width / LbSlideCaptcha.imageWidth;
    final height = LbSlideCaptcha.imageHeight * scale;
    if (captcha == null) {
      return SizedBox(
        height: height,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    final pieceX = captcha.pieceX(_offset, width, _knobWidth);
    return ClipRSuperellipse(
      borderRadius: AppRadius.sm,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: Image.memory(
                captcha.image,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
            Positioned(
              left: pieceX * scale,
              top: captcha.thumbY * scale,
              width: captcha.thumbWidth * scale,
              height: captcha.thumbHeight * scale,
              child: Image.memory(
                captcha.thumb,
                fit: BoxFit.fill,
                gaplessPlayback: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrack(double width, LbColors colors) {
    final travel = width - _knobWidth;
    final enabled = _captcha != null && !_busy;
    return SizedBox(
      height: _trackHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: colors.accentSoft,
                shape: AppShape.full,
              ),
            ),
          ),
          Positioned(
            left: _offset,
            top: 0,
            bottom: 0,
            width: _knobWidth,
            child: GestureDetector(
              onHorizontalDragUpdate: enabled
                  ? (details) => setState(() {
                      _offset = (_offset + details.delta.dx).clamp(0, travel);
                    })
                  : null,
              onHorizontalDragEnd: enabled
                  ? (_) => unawaited(_submit(width))
                  : null,
              child: DecoratedBox(
                decoration: ShapeDecoration(
                  color: enabled ? colors.accent : colors.rule,
                  shape: AppShape.full,
                ),
                child: Center(
                  child: GlyphIcon(
                    AppGlyphs.chevronForward,
                    color: colors.accentInk,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
