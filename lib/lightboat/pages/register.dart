import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/panel_api.dart';
import 'package:fl_clash/lightboat/pages/captcha.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LbRegisterPage extends ConsumerStatefulWidget {
  const LbRegisterPage({super.key});

  @override
  ConsumerState<LbRegisterPage> createState() => _LbRegisterPageState();
}

class _LbRegisterPageState extends ConsumerState<LbRegisterPage> {
  /// The panel's `verify_code_interval`; it rejects earlier resends anyway.
  static const _resendAfter = 60;

  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteController = TextEditingController();
  Timer? _countdown;
  int _secondsLeft = 0;
  bool _obscure = true;
  bool _sending = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _countdown?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  void _show(String message, {bool error = true}) {
    setState(() {
      _message = message;
      _messageIsError = error;
    });
  }

  void _startCountdown() {
    _countdown?.cancel();
    setState(() => _secondsLeft = _resendAfter);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsLeft <= 1) {
        timer.cancel();
        if (mounted) setState(() => _secondsLeft = 0);
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _show(LbStrings.emailFirst);
      return;
    }
    final ticket = await showSlideCaptcha(context);
    if (ticket == null || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(lbPanelApiProvider)
          .sendEmailCode(email: email, captchaTicket: ticket);
      if (!mounted) return;
      _startCountdown();
      _show(LbStrings.codeSent, error: false);
    } catch (error) {
      if (mounted) _show(LbStrings.panelError(error, action: '发送'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final invite = _inviteController.text.trim();
    if (email.isEmpty || code.isEmpty || password.isEmpty) {
      _show(LbStrings.registerFieldsRequired);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = null;
    });
    final session = ref.read(lbSessionProvider.notifier);
    Future<void> attempt(String? ticket) => session.register(
      email: email,
      password: password,
      code: code,
      invite: invite.isEmpty ? null : invite,
      captchaTicket: ticket,
    );
    try {
      try {
        await attempt(null);
      } on PanelException catch (error) {
        if (error.code != LbErrorCode.captchaRequired || !mounted) rethrow;
        final ticket = await showSlideCaptcha(context);
        if (ticket == null) return;
        await attempt(ticket);
      }
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (mounted) _show(LbStrings.panelError(error, action: '注册'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final message = _message;
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: const Text(LbStrings.registerTitle),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: LbStrings.email),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: LbStrings.code,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 56,
                      child: OutlinedButton(
                        onPressed: _sending || _secondsLeft > 0
                            ? null
                            : () => unawaited(_sendCode()),
                        child: Text(
                          _secondsLeft > 0
                              ? LbStrings.resendIn(_secondsLeft)
                              : LbStrings.sendCode,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: LbStrings.passwordHint,
                    suffixIcon: IconButton(
                      tooltip: LbStrings.password,
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: GlyphIcon(
                        _obscure ? AppGlyphs.eye : AppGlyphs.eyeOff,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _inviteController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_register()),
                  decoration: const InputDecoration(
                    labelText: LbStrings.inviteOptional,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    message,
                    style: textTheme.bodyMedium?.copyWith(
                      color: _messageIsError ? colors.seal : colors.accent,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.accent,
                      foregroundColor: colors.accentInk,
                    ),
                    onPressed: _busy ? null : () => unawaited(_register()),
                    child: _busy
                        ? SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: colors.accent,
                            ),
                          )
                        : const Text(LbStrings.register),
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
