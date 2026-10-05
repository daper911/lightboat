import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/icons/icons.dart';
import 'package:fl_clash/lightboat/line_groups.dart';
import 'package:fl_clash/lightboat/logic/connection.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

Future<void> showLbLines(BuildContext context) {
  return Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const _LbLinesPage()));
}

class _LbLinesPage extends ConsumerWidget {
  const _LbLinesPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final line = ref.watch(lbLineInfoProvider);
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: const Text(LbStrings.line),
        actions: [
          if (line != null)
            TextButton(
              onPressed: () =>
                  ref.read(lbConnectionProvider.notifier).testLines(line),
              child: const Text(LbStrings.testDelay),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: line == null
          ? Center(
              child: Text(
                LbStrings.linesNotReady,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: colors.muted,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: line.choices.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, index) =>
                  _LineTile(group: line.group, proxy: line.choices[index]),
            ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  final Group group;
  final Proxy proxy;

  const _LineTile({required this.group, required this.proxy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final selected = group.now == proxy.name;
    final delay = ref.watch(
      delayProvider(proxyName: proxy.name, testUrl: group.testUrl),
    );
    return Material(
      color: selected ? colors.accentSoft : Colors.transparent,
      shape: AppShape.xl.copyWith(
        side: BorderSide(color: selected ? colors.accent : colors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: AppShape.xl,
        onTap: () => ref
            .read(lbConnectionProvider.notifier)
            .selectLine(group.name, proxy.name),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  lbLineName(proxy.name),
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: colors.ink,
                  ),
                ),
              ),
              Text(
                lbDelayText(delay) ?? '',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: delay != null && delay <= 0
                      ? colors.seal
                      : colors.muted,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                GlyphIcon(AppGlyphs.check, color: colors.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
