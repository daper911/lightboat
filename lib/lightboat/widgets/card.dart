import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/lightboat/theme.dart';
import 'package:material_ui/material_ui.dart';

class LbCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  const LbCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final colors = LbColors.of(context);
    return Material(
      color: Colors.transparent,
      shape: AppShape.xl.copyWith(side: BorderSide(color: colors.rule)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: AppShape.xl,
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
