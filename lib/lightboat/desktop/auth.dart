import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/logic/account.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/captcha.dart';
import 'package:fl_clash/lightboat/widgets/card.dart';
import 'package:fl_clash/lightboat/widgets/logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Signs in again while the session lives on, e.g. after the JWT expired.
Future<void> showLbDesktopLogin(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(LbStrings.relogin),
      content: SizedBox(
        width: LbDesktopAuthPage.cardWidth,
        child: _LoginForm(onSignedIn: () => Navigator.of(context).pop()),
      ),
    ),
  );
}

class LbDesktopAuthPage extends StatefulWidget {
  static const cardWidth = 400.0;

  const LbDesktopAuthPage({super.key});

  @override
  State<LbDesktopAuthPage> createState() => _LbDesktopAuthPageState();
}

class _LbDesktopAuthPageState extends State<LbDesktopAuthPage> {
  bool _registering = false;

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final muted = textTheme.bodySmall?.copyWith(color: colors.muted);
    Widget link(String label, String url) => TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: textTheme.bodySmall,
      ),
      onPressed: () => unawaited(lbOpenUrl(url)),
      child: Text(label),
    );
    return Scaffold(
      backgroundColor: colors.paper,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: SizedBox(
            width: LbDesktopAuthPage.cardWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: LbLogo(size: 64)),
                const SizedBox(height: 12),
                Text(
                  LbStrings.appName,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineMedium?.copyWith(
                    color: colors.ink,
                    fontFamily: lbSerif,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  LbStrings.slogan,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colors.muted,
                    fontFamily: lbSerif,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 28),
                LbCard(
                  padding: const EdgeInsets.all(24),
                  child: _registering
                      ? _RegisterForm(
                          onBack: () => setState(() => _registering = false),
                        )
                      : _LoginForm(
                          onRegister: () => setState(() => _registering = true),
                        ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(LbStrings.agreePrefix, style: muted),
                    link(LbStrings.tos, LbConfig.tosUrl),
                    Text('·', style: muted),
                    link(LbStrings.privacy, LbConfig.privacyUrl),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final TextInputAction action;
  final List<String> autofillHints;
  final VoidCallback? onSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.action,
    required this.autofillHints,
    this.onSubmitted,
  });

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      obscureText: _obscure,
      autofillHints: widget.autofillHints,
      textInputAction: widget.action,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: widget.label,
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: GlyphIcon(_obscure ? AppGlyphs.eye : AppGlyphs.eyeOff),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  final bool error;

  const _Message(this.text, {this.error = true});

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        text,
        style: context.textTheme.bodyMedium?.copyWith(
          color: error ? colors.seal : colors.accent,
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton(
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(label),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  final VoidCallback? onRegister;
  final VoidCallback? onSignedIn;

  const _LoginForm({this.onRegister, this.onSignedIn});

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = LbStrings.emailRequired);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final session = ref.read(lbSessionProvider.notifier);
    try {
      final signedIn = await lbWithCaptcha(
        (ticket) => session.login(
          email: email,
          password: password,
          captchaTicket: ticket,
        ),
        () async => mounted ? showSlideCaptcha(context) : null,
      );
      if (signedIn) widget.onSignedIn?.call();
    } catch (error) {
      if (mounted) setState(() => _error = LbStrings.loginError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onRegister = widget.onRegister;
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: LbStrings.email),
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: _passwordController,
            label: LbStrings.password,
            action: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onSubmitted: () => unawaited(_login()),
          ),
          if (_error != null) _Message(_error!),
          const SizedBox(height: 20),
          _SubmitButton(
            label: LbStrings.login,
            busy: _busy,
            onPressed: () => unawaited(_login()),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => unawaited(lbOpenUrl(LbConfig.registerUrl)),
                child: const Text(LbStrings.forgotPassword),
              ),
              if (onRegister != null)
                TextButton(
                  onPressed: onRegister,
                  child: const Text(LbStrings.registerLink),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RegisterForm extends ConsumerStatefulWidget {
  final VoidCallback onBack;

  const _RegisterForm({required this.onBack});

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _inviteController = TextEditingController();
  final _countdown = LbResendCountdown();
  bool _sending = false;
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void dispose() {
    _countdown.dispose();
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  void _show(String message, {bool error = true}) => setState(() {
    _message = message;
    _messageIsError = error;
  });

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
      _countdown.start();
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
    setState(() {
      _busy = true;
      _message = null;
    });
    final session = ref.read(lbSessionProvider.notifier);
    try {
      await lbWithCaptcha(
        (ticket) => session.register(
          email: email,
          password: password,
          code: code,
          invite: invite.isEmpty ? null : invite,
          captchaTicket: ticket,
        ),
        () async => mounted ? showSlideCaptcha(context) : null,
      );
    } catch (error) {
      if (mounted) _show(LbStrings.panelError(error, action: '注册'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final message = _message;
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            LbStrings.registerTitle,
            style: context.textTheme.titleMedium?.copyWith(
              color: LbColors.of(context).ink,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: LbStrings.email),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: LbStrings.code),
                ),
              ),
              const SizedBox(width: 12),
              ValueListenableBuilder<int>(
                valueListenable: _countdown,
                builder: (_, secondsLeft, _) => OutlinedButton(
                  onPressed: _sending || secondsLeft > 0
                      ? null
                      : () => unawaited(_sendCode()),
                  child: Text(
                    secondsLeft > 0
                        ? LbStrings.resendIn(secondsLeft)
                        : LbStrings.sendCode,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _PasswordField(
            controller: _passwordController,
            label: LbStrings.passwordHint,
            action: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _inviteController,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => unawaited(_register()),
            decoration: const InputDecoration(
              labelText: LbStrings.inviteOptional,
            ),
          ),
          if (message != null) _Message(message, error: _messageIsError),
          const SizedBox(height: 20),
          _SubmitButton(
            label: LbStrings.register,
            busy: _busy,
            onPressed: () => unawaited(_register()),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: widget.onBack,
              child: const Text(LbStrings.backToLogin),
            ),
          ),
        ],
      ),
    );
  }
}
