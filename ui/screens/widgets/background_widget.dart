import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:tech_borrow/ui/screens/utility/app_colors.dart';
import 'package:tech_borrow/ui/screens/utility/asset_paths.dart';

class BackgroundWidget extends StatelessWidget {
  const BackgroundWidget({super.key, required this.child, this.showLogo = false});

  final Widget child;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Appcolors.background,
      child: Stack(
        children: [
          if (showLogo)
            Center(
              child: SvgPicture.asset(
                AssetPaths.appLogoSvg,
                width: 140,
              ),
            ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}
