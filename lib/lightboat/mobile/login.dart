import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/config.dart';
import 'package:fl_clash/lightboat/logic/account.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/widgets/captcha.dart';
import 'package:fl_clash/lightboat/widgets/logo.dart';
import 'package:fl_clash/lightboat/mobile/register.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LbLoginPage extends ConsumerStatefulWidget {
  const LbLoginPage({super.key});

  @override
  ConsumerState<LbLoginPage> createState() => _LbLoginPageState();
}

class _LbLoginPageState extends ConsumerState<LbLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
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
    FocusScope.of(context).unfocus();
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
      if (signedIn && mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) setState(() => _error = LbStrings.loginError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: colors.paper,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: LbLogo()),
                      const SizedBox(height: 16),
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
                      const SizedBox(height: 6),
                      Text(
                        LbStrings.slogan,
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.muted,
                          fontFamily: lbSerif,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 40),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: LbStrings.email,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscure,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => unawaited(_login()),
                        decoration: InputDecoration(
                          labelText: LbStrings.password,
                          suffixIcon: IconButton(
                            tooltip: LbStrings.password,
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: GlyphIcon(
                              _obscure ? AppGlyphs.eye : AppGlyphs.eyeOff,
                            ),
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          _error!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.seal,
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
                          onPressed: _busy ? null : () => unawaited(_login()),
                          child: _busy
                              ? SizedBox.square(
                                  dimension: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: colors.accent,
                                  ),
                                )
                              : const Text(LbStrings.login),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const LbRegisterPage(),
                              ),
                            ),
                            child: const Text(LbStrings.registerLink),
                          ),
                          TextButton(
                            onPressed: () =>
                                unawaited(lbOpenUrl(LbConfig.registerUrl)),
                            child: const Text(LbStrings.forgotPassword),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            LbStrings.agreePrefix,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.muted,
                            ),
                          ),
                          _SmallLink(
                            label: LbStrings.tos,
                            url: LbConfig.tosUrl,
                          ),
                          Text(
                            '·',
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.muted,
                            ),
                          ),
                          _SmallLink(
                            label: LbStrings.privacy,
                            url: LbConfig.privacyUrl,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallLink extends StatelessWidget {
  final String label;
  final String url;

  const _SmallLink({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: context.textTheme.bodySmall,
      ),
      onPressed: () => unawaited(lbOpenUrl(url)),
      child: Text(label),
    );
  }
}
