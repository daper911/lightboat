import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/pages/home.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Announcements are short; plain text keeps them readable without a Markdown
/// renderer. Links keep their address so they can still be copied.
String lbMarkdownToText(String markdown) => markdown
    .replaceAllMapped(RegExp(r'!\[([^\]]*)\]\(([^)]*)\)'), (m) => m[1] ?? '')
    .replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
      (m) => m[1] == m[2] ? m[2]! : '${m[1]}（${m[2]}）',
    )
    .replaceAll(RegExp(r'^\s{0,3}#{1,6}\s*', multiLine: true), '')
    .replaceAll(RegExp(r'^\s{0,3}>\s?', multiLine: true), '')
    .replaceAll(RegExp(r'^\s*[-*+]\s+', multiLine: true), '· ')
    .replaceAll(RegExp(r'(\*\*|__|~~|`)'), '')
    .replaceAll(RegExp(r'<[^>]+>'), '')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

final lbAnnouncementsProvider =
    FutureProvider.autoDispose<List<LbAnnouncement>>(
      (ref) => ref
          .read(lbSessionProvider.notifier)
          .authed((api, jwt) => api.announcements(jwt)),
    );

const _seenKey = 'lb_seen_popup_announcements';

/// Shows the newest `popup` announcement the user has not seen, once.
Future<void> lbShowPopupAnnouncement(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!ref.read(lbSessionProvider).hasJwt) return;
  try {
    final items = await ref.read(lbAnnouncementsProvider.future);
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getStringList(_seenKey) ?? const [];
    final next = items.firstWhereOrNull(
      (item) => item.popup && !seen.contains('${item.id}'),
    );
    if (next == null) return;
    await prefs.setStringList(_seenKey, [...seen, '${next.id}']);
    if (context.mounted) await _showAnnouncement(context, next);
  } catch (error) {
    commonPrint.log('lightboat announcements: $error');
  }
}

Future<void> _showAnnouncement(BuildContext context, LbAnnouncement item) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(item.title),
      content: SingleChildScrollView(
        child: SelectableText(lbMarkdownToText(item.content)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(LbStrings.gotIt),
        ),
      ],
    ),
  );
}

class LbAnnouncementsPage extends ConsumerWidget {
  const LbAnnouncementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = LbColors.of(context);
    final announcements = ref.watch(lbAnnouncementsProvider);
    Widget note(String text) => Center(
      child: Text(
        text,
        style: context.textTheme.bodyMedium?.copyWith(color: colors.muted),
      ),
    );
    return Scaffold(
      backgroundColor: colors.paper,
      appBar: AppBar(
        backgroundColor: colors.paper,
        surfaceTintColor: Colors.transparent,
        title: const Text(LbStrings.announcements),
      ),
      body: announcements.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            note(LbStrings.panelError(error, action: LbStrings.loadAction)),
        data: (items) => items.isEmpty
            ? note(LbStrings.noAnnouncements)
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return LbCard(
                    onTap: () => unawaited(_showAnnouncement(context, item)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.pinned ? LbStrings.pinnedMark : ''}'
                          '${item.title}',
                          style: context.textTheme.titleMedium?.copyWith(
                            color: colors.ink,
                          ),
                        ),
                        if (item.createdAt > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            lbFormatDate(item.createdAt),
                            style: context.textTheme.bodySmall?.copyWith(
                              color: colors.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          lbMarkdownToText(item.content),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
