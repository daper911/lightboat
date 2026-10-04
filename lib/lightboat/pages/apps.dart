import 'dart:async';

import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/lightboat/strings.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/plugins/app.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Edits FlClash's access control in place; FlClash itself offers the
/// reconnect a running VPN needs once the page saves on the way out.
class LbAppsPage extends ConsumerStatefulWidget {
  const LbAppsPage({super.key});

  @override
  ConsumerState<LbAppsPage> createState() => _LbAppsPageState();
}

class _LbAppsPageState extends ConsumerState<LbAppsPage> {
  final _searchController = TextEditingController();
  late AccessControlProps _props;
  late final AccessControlProps _initial;
  bool _loading = true;
  bool _permissionGranted = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _initial = ref.read(vpnSettingProvider).accessControlProps;
    _props = _initial;
    unawaited(_loadPackages());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    final action = ref.read(systemActionProvider.notifier);
    final packages = await action.getPackages();
    final granted =
        packages.isNotEmpty || await action.isInstalledAppsPermissionGranted();
    if (!mounted) return;
    setState(() {
      _permissionGranted = granted;
      _loading = false;
    });
  }

  Future<void> _grantPermission() async {
    final granted = await ref
        .read(systemActionProvider.notifier)
        .requestInstalledAppsPermission();
    if (!granted) {
      await app?.openAppSettings();
      return;
    }
    if (mounted) setState(() => _loading = true);
    await _loadPackages();
  }

  Future<void> _pickChinaApps() async {
    final china = (await app?.getChinaPackageNames() ?? const []).toSet();
    if (!mounted || china.isEmpty) return;
    final installed = ref
        .read(packagesProvider)
        .map((item) => item.packageName)
        .where(china.contains);
    setState(() {
      _props = _props
          .copyWith(enable: true, mode: AccessControlMode.rejectSelected)
          .copyWithNewList({..._props.rejectList, ...installed}.toList());
    });
  }

  void _toggle(String packageName) {
    final selected = Set<String>.from(_props.currentList);
    if (!selected.remove(packageName)) selected.add(packageName);
    setState(() => _props = _props.copyWithNewList(selected.toList()..sort()));
  }

  void _save() {
    if (_props == _initial) return;
    ref
        .read(vpnSettingProvider.notifier)
        .update((state) => state.copyWith(accessControlProps: _props));
  }

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: colors.paper,
        appBar: AppBar(
          backgroundColor: colors.paper,
          surfaceTintColor: Colors.transparent,
          title: const Text(LbStrings.splitTunnel),
        ),
        body: _buildBody(context, colors),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LbColors colors) {
    final textTheme = context.textTheme;
    final header = <Widget>[
      SwitchListTile(
        title: const Text(LbStrings.splitEnable),
        value: _props.enable,
        onChanged: (value) =>
            setState(() => _props = _props.copyWith(enable: value)),
      ),
      if (_props.enable)
        RadioGroup<AccessControlMode>(
          groupValue: _props.mode,
          onChanged: (mode) {
            if (mode != null) {
              setState(() => _props = _props.copyWith(mode: mode));
            }
          },
          child: const Column(
            children: [
              RadioListTile<AccessControlMode>(
                value: AccessControlMode.rejectSelected,
                title: Text(LbStrings.splitExclude),
                subtitle: Text(LbStrings.splitExcludeHint),
              ),
              RadioListTile<AccessControlMode>(
                value: AccessControlMode.acceptSelected,
                title: Text(LbStrings.splitInclude),
                subtitle: Text(LbStrings.splitIncludeHint),
              ),
            ],
          ),
        ),
    ];
    if (!_props.enable) {
      return ListView(children: header);
    }
    if (_loading) {
      return ListView(
        children: [
          ...header,
          const SizedBox(height: 32),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 12),
          Center(
            child: Text(LbStrings.splitLoading, style: textTheme.bodyMedium),
          ),
        ],
      );
    }
    if (!_permissionGranted) {
      return ListView(
        children: [
          ...header,
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  LbStrings.splitNeedPermission,
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(color: colors.ink),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => unawaited(_grantPermission()),
                  child: const Text(LbStrings.splitGrant),
                ),
              ],
            ),
          ),
        ],
      );
    }
    final selected = _props.currentList.toSet();
    final query = _query.toLowerCase();
    final apps =
        ref
            .watch(packagesProvider)
            .whereVisible(
              isFilterSystemApp: _props.isFilterSystemApp,
              isFilterNonInternetApp: _props.isFilterNonInternetApp,
            )
            .where(
              (item) =>
                  query.isEmpty ||
                  item.label.toLowerCase().contains(query) ||
                  item.packageName.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) {
            final pinned =
                (selected.contains(b.packageName) ? 1 : 0) -
                (selected.contains(a.packageName) ? 1 : 0);
            return pinned != 0 ? pinned : a.label.compareTo(b.label);
          });
    return ListView.builder(
      itemCount: header.length + 1 + apps.length,
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        if (index == header.length) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_props.mode == AccessControlMode.rejectSelected)
                  OutlinedButton(
                    onPressed: () => unawaited(_pickChinaApps()),
                    child: const Text(LbStrings.splitPickChina),
                  ),
                const SizedBox(height: 8),
                TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value.trim()),
                  decoration: const InputDecoration(
                    labelText: LbStrings.splitSearch,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        LbStrings.splitSelected(selected.length),
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.muted,
                        ),
                      ),
                    ),
                    Text(
                      LbStrings.splitShowSystem,
                      style: textTheme.bodyMedium,
                    ),
                    Switch(
                      value: !_props.isFilterSystemApp,
                      onChanged: (value) => setState(
                        () =>
                            _props = _props.copyWith(isFilterSystemApp: !value),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
        final package = apps[index - header.length - 1];
        return CheckboxListTile(
          value: selected.contains(package.packageName),
          onChanged: (_) => _toggle(package.packageName),
          secondary: PackageIcon(packageName: package.packageName, size: 40),
          title: Text(package.label, maxLines: 1),
          subtitle: Text(
            package.packageName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      },
    );
  }
}
