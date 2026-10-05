import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/logic/account.dart';
import 'package:fl_clash/lightboat/logic/format.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/lightboat/widgets/card.dart';
import 'package:fl_clash/lightboat/widgets/prompts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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
                    onTap: () => unawaited(lbShowAnnouncement(context, item)),
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
