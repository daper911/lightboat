import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/desktop/home.dart';
import 'package:fl_clash/lightboat/desktop/lines.dart';
import 'package:fl_clash/lightboat/desktop/me.dart';
import 'package:fl_clash/lightboat/desktop/purchase.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/logo.dart';
import 'package:fl_clash/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum LbDesktopTab { home, lines, purchase, me }

class LbDesktopNav {
  final LbDesktopTab tab;

  /// The subscription the purchase page renews; null buys a new plan.
  final LbSubscription? renewing;

  const LbDesktopNav({this.tab = LbDesktopTab.home, this.renewing});
}

final lbDesktopNavProvider = NotifierProvider<LbDesktopNavigator, LbDesktopNav>(
  LbDesktopNavigator.new,
);

class LbDesktopNavigator extends Notifier<LbDesktopNav> {
  @override
  LbDesktopNav build() => const LbDesktopNav();

  void go(LbDesktopTab tab) => state = LbDesktopNav(tab: tab);

  Future<void> openPurchase(LbSubscription? renewing) async {
    state = LbDesktopNav(tab: LbDesktopTab.purchase, renewing: renewing);
  }
}

class LbDesktopShell extends ConsumerWidget {
  static const sidebarWidth = 224.0;
  static const contentMaxWidth = 960.0;

  const LbDesktopShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final nav = ref.watch(lbDesktopNavProvider);
    final page = switch (nav.tab) {
      LbDesktopTab.home => const LbDesktopHome(),
      LbDesktopTab.lines => const LbDesktopLines(),
      LbDesktopTab.purchase => LbDesktopPurchase(
        key: ValueKey(nav.renewing?.id),
        renewing: nav.renewing,
      ),
      LbDesktopTab.me => const LbDesktopMe(),
    };
    return Scaffold(
      backgroundColor: colors.paper,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: sidebarWidth, child: _Sidebar()),
          VerticalDivider(width: 1, thickness: 1, color: colors.rule),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: contentMaxWidth),
                child: page,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A desktop page: the title, then its content, scrolling as one column.
class LbDesktopPage extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Widget? action;

  const LbDesktopPage({
    super.key,
    required this.title,
    required this.children,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: context.textTheme.headlineSmall?.copyWith(
                  color: colors.ink,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 20),
        ...children,
      ],
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final textTheme = context.textTheme;
    final tab = ref.watch(lbDesktopNavProvider.select((nav) => nav.tab));
    final navigator = ref.read(lbDesktopNavProvider.notifier);
    Widget item(LbDesktopTab target, Glyph glyph, String label) => _NavItem(
      glyph: glyph,
      label: label,
      selected: tab == target,
      onTap: () => navigator.go(target),
    );
    return FocusTraversalGroup(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const LbLogo(size: 28),
                  const SizedBox(width: 10),
                  Text(
                    LbStrings.appName,
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.ink,
                      fontFamily: lbSerif,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _NavSection(LbStrings.navConsole),
            item(LbDesktopTab.home, AppGlyphs.dashboard, LbStrings.home),
            item(LbDesktopTab.lines, AppGlyphs.proxies, LbStrings.line),
            item(
              LbDesktopTab.purchase,
              AppGlyphs.sparkle,
              LbStrings.buyPlanNav,
            ),
            const SizedBox(height: 12),
            const _NavSection(LbStrings.navAccount),
            item(LbDesktopTab.me, AppGlyphs.account, LbStrings.me),
            const Spacer(),
            Divider(color: colors.rule),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                LbStrings.slogan,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.muted,
                  fontFamily: lbSerif,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'v${globalState.packageInfo.version}',
                style: textTheme.bodySmall?.copyWith(color: colors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavSection extends StatelessWidget {
  final String title;

  const _NavSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: Text(
        title,
        style: context.textTheme.labelMedium?.copyWith(
          color: LbColors.of(context).muted,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final Glyph glyph;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.glyph,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final color = selected ? colors.accent : colors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? colors.accentSoft : Colors.transparent,
        shape: AppShape.sm,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: AppShape.sm,
          onTap: onTap,
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  GlyphIcon(glyph, size: 18, color: color),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: context.textTheme.bodyLarge?.copyWith(
                      color: color,
                      fontWeight: selected ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
