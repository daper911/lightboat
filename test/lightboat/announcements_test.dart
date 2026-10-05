import 'package:fl_clash/lightboat/api/models.dart';
import 'package:fl_clash/lightboat/auth/credential_store.dart';
import 'package:fl_clash/lightboat/logic/account.dart';
import 'package:fl_clash/lightboat/mobile/announcements.dart';
import 'package:fl_clash/lightboat/widgets/prompts.dart';
import 'package:fl_clash/lightboat/session.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';
import 'fakes.dart';

const _items = [
  LbAnnouncement(id: 1, title: '旧通知', content: '内容一', createdAt: 1),
  LbAnnouncement(
    id: 2,
    title: '国庆维护',
    content:
        '## 维护\n**10 月 6 日** 凌晨维护，详见 [教程](https://ssr.cnbetx.com/#/document)',
    popup: true,
    pinned: true,
    createdAt: 0,
  ),
];

void main() {
  test('turns Markdown into readable text', () {
    expect(
      lbMarkdownToText(_items[1].content),
      '维护\n10 月 6 日 凌晨维护，详见 教程（https://ssr.cnbetx.com/#/document）',
    );
    expect(lbMarkdownToText('- 一\n- 二'), '· 一\n· 二');
  });

  test('drops hidden announcements and puts pinned ones first', () {
    final list = LbAnnouncement.listFrom({
      'announcements': [
        {'id': 1, 'title': 'a', 'show': true, 'created_at': 5},
        {'id': 2, 'title': 'b', 'show': false},
        {'id': 3, 'title': 'c', 'pinned': true, 'created_at': 1},
        {'id': 4, 'title': 'd', 'created_at': 9},
      ],
    });
    expect([for (final item in list) item.id], [3, 4, 1]);
  });

  late ProviderContainer container;

  late WidgetRef ref;

  Future<BuildContext> pump(WidgetTester tester, Widget child) async {
    SharedPreferences.setMockInitialValues({});
    final api = FakePanelApi()..announcementList = _items;
    container = ProviderContainer(
      overrides: [
        lbPanelApiProvider.overrideWithValue(api),
        lbCredentialStoreProvider.overrideWithValue(
          MemoryStore()..saved = const LbStoredSession(jwt: 'jwt'),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(lbSessionProvider.notifier).restore();
    late BuildContext context;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: TestApp(
          child: Consumer(
            builder: (ctx, widgetRef, _) {
              context = ctx;
              ref = widgetRef;
              return child;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return context;
  }

  testWidgets('lists announcements and opens one', (tester) async {
    await pump(tester, const LbAnnouncementsPage());

    expect(find.text('${LbStrings.pinnedMark}国庆维护'), findsOneWidget);
    expect(find.text('旧通知'), findsOneWidget);
    await tester.tap(find.text('旧通知'));
    await tester.pumpAndSettle();
    expect(find.text(LbStrings.gotIt), findsOneWidget);
  });

  testWidgets('a popup announcement shows only once', (tester) async {
    final context = await pump(tester, const Scaffold());

    final first = lbShowPopupAnnouncement(context, ref);
    await tester.pumpAndSettle();
    expect(find.text('国庆维护'), findsOneWidget);
    await tester.tap(find.text(LbStrings.gotIt));
    await tester.pumpAndSettle();
    await first;

    await lbShowPopupAnnouncement(context, ref);
    await tester.pumpAndSettle();
    expect(find.text('国庆维护'), findsNothing);
  });
}
