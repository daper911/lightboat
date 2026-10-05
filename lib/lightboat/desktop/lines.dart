import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/desktop/shell.dart';
import 'package:fl_clash/lightboat/line_groups.dart';
import 'package:fl_clash/lightboat/logic/connection.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class LbDesktopLines extends ConsumerWidget {
  const LbDesktopLines({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final line = ref.watch(lbLineInfoProvider);
    final connection = ref.read(lbConnectionProvider.notifier);
    return LbDesktopPage(
      title: LbStrings.line,
      action: line == null
          ? null
          : OutlinedButton.icon(
              onPressed: () => connection.testLines(line),
              icon: const GlyphIcon(AppGlyphs.speed, size: 18),
              label: const Text(LbStrings.testDelay),
            ),
      children: [
        if (line == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                LbStrings.linesNotReady,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
            ),
          )
        else
          Material(
            color: Colors.transparent,
            shape: AppShape.xl.copyWith(side: BorderSide(color: colors.rule)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const _HeaderRow(),
                for (final proxy in line.choices)
                  _LineRow(
                    group: line.group,
                    proxy: proxy,
                    onTap: () =>
                        connection.selectLine(line.group.name, proxy.name),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    final style = context.textTheme.labelMedium?.copyWith(color: colors.muted);
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.rule)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(LbStrings.line, style: style)),
          SizedBox(width: 120, child: Text(LbStrings.delay, style: style)),
          const SizedBox(width: 72),
        ],
      ),
    );
  }
}

class _LineRow extends ConsumerWidget {
  final Group group;
  final Proxy proxy;
  final VoidCallback onTap;

  const _LineRow({
    required this.group,
    required this.proxy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final selected = group.now == proxy.name;
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    return Material(
      color: selected ? colors.accentSoft : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.rule)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lbLineName(proxy.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: selected ? colors.accent : colors.ink,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  lbDelayText(delay) ?? '—',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: delay != null && delay <= 0
                        ? colors.seal
                        : colors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(
                width: 72,
                child: selected
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          GlyphIcon(
                            AppGlyphs.check,
                            size: 18,
                            color: colors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LbStrings.current,
                            style: context.textTheme.labelMedium?.copyWith(
                              color: colors.accent,
                            ),
                          ),
                        ],
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
