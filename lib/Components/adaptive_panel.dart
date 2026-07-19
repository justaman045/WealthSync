import 'package:flutter/material.dart';
import 'package:money_control/Utils/responsive.dart';

class AdaptivePanel extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final bool showDetail;
  final int masterFlex;
  final int detailFlex;

  const AdaptivePanel({
    super.key,
    required this.master,
    this.detail,
    this.showDetail = false,
    this.masterFlex = 2,
    this.detailFlex = 3,
  });

  @override
  Widget build(BuildContext context) {
    final isWide = Responsive.isTablet(context) &&
        Responsive.isLandscape(context);

    if (isWide && showDetail && detail != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: masterFlex,
            child: master,
          ),
          Container(
            width: 1,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.1),
          ),
          Expanded(
            flex: detailFlex,
            child: detail!,
          ),
        ],
      );
    }

    return master;
  }
}
