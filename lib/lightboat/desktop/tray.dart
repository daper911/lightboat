import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/line_groups.dart';
import 'package:fl_clash/lightboat/logic/connection.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tray/tray.dart';

/// Replaces FlClash's tray, whose menu exposes TUN, the system proxy switch
/// and environment variables, with the few actions W3 §6 lists.
class LbTray implements TrayPort {
  bool _isShutDown = false;

  static String icon({required bool running}) => running
      ? 'assets/lightboat/tray/connected.ico'
      : 'assets/lightboat/tray/disconnected.ico';

  @override
  Future<void> shutdown() async {
    _isShutDown = true;
    await Tray.instance.hide();
  }

  @override
  Future<void> update({
    required TrayState trayState,
    required Traffic traffic,
    required ProviderReader read,
  }) async {
    if (_isShutDown) return;
    final menu = lbTrayMenu(trayState: trayState, read: read);
    await Tray.instance.show(
      TraySpec(
        icon: TrayIcon.asset(icon(running: trayState.isStart), size: 16),
        toolTip: '${LbStrings.appName} · ${_status(trayState, read)}',
        menu: menu,
      ),
    );
  }
}

String _status(TrayState trayState, ProviderReader read) {
  final line = read(lbLineInfoProvider);
  final node = line == null ? null : line.autoNode ?? lbLineName(line.current);
  return LbStrings.trayStatus(running: trayState.isStart, node: node);
}

List<TrayMenuItem> lbTrayMenu({
  required TrayState trayState,
  required ProviderReader read,
}) {
  final connection = read(lbConnectionProvider.notifier);
  return [
    TrayMenuAction(label: _status(trayState, read), enabled: false),
    const TrayMenuSeparator(),
    TrayMenuAction(
      label: trayState.isStart ? LbStrings.disconnect : LbStrings.connect,
      onSelected: connection.toggle,
    ),
    TrayMenuSubmenu(
      label: LbStrings.mode,
      items: [
        TrayMenuCheckbox(
          label: LbStrings.modeSmart,
          checked: trayState.mode != Mode.global,
          onSelected: () => connection.changeMode(Mode.rule),
        ),
        TrayMenuCheckbox(
          label: LbStrings.modeGlobal,
          checked: trayState.mode == Mode.global,
          onSelected: () => connection.changeMode(Mode.global),
        ),
      ],
    ),
    const TrayMenuSeparator(),
    TrayMenuAction(
      label: LbStrings.openApp,
      onSelected: () => windowPort?.show(),
    ),
    TrayMenuAction(
      label: LbStrings.quit,
      onSelected: () => read(systemActionProvider.notifier).handleExit(),
    ),
  ];
}

const _trayExplainedKey = 'lb_tray_explained';

/// The first close only hides the window; say once where Lightboat went.
Future<void> lbExplainTrayOnce() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_trayExplainedKey) == true) return;
  final context = globalState.navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  await prefs.setBool(_trayExplainedKey, true);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text(LbStrings.trayHintTitle),
      content: const Text(LbStrings.trayHint),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(LbStrings.gotIt),
        ),
      ],
    ),
  );
}
