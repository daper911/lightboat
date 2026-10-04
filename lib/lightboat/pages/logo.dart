import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

const _sealSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  <rect x="2" y="2" width="60" height="60" rx="9" fill="#c5372f"/>
  <g fill="none" stroke="#fbf8f1" stroke-linecap="round" stroke-linejoin="round">
    <path d="M14 36 C 22 44, 42 44, 50 36" stroke-width="4"/>
    <path d="M24 35 C 25 27, 39 27, 40 35" stroke-width="3.5"/>
    <path d="M44 34 L 51 18" stroke-width="3"/>
    <path d="M12 48 C 18 45, 24 51, 30 48 S 42 45, 52 48" stroke-width="2.5"/>
  </g>
</svg>
''';

class LbLogo extends StatelessWidget {
  final double size;

  const LbLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(_sealSvg, width: size, height: size);
  }
}
