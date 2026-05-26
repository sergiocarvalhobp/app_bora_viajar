import 'package:flutter/material.dart';

import 'forest_hero_background.dart';

/// Título branco padrão das AppBars com fundo verde.
const kBvForestAppBarTitleStyle = TextStyle(
  fontFamily: 'DMSerifDisplay',
  fontSize: 20,
  color: Colors.white,
);

/// AppBar com [ForestHeroBackground] (verde + pontos, igual login/home).
class BvForestAppBar extends StatelessWidget implements PreferredSizeWidget {
  const BvForestAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.bottom,
    this.centerTitle = false,
  }) : assert(title != null || titleWidget != null);

  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;
  final PreferredSizeWidget? bottom;
  final bool centerTitle;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      automaticallyImplyLeading: automaticallyImplyLeading,
      centerTitle: centerTitle,
      flexibleSpace: const ForestHeroBackground(),
      leading: leading,
      title: titleWidget ??
          Text(
            title!,
            style: kBvForestAppBarTitleStyle,
          ),
      actions: actions,
      bottom: bottom,
    );
  }
}

/// Estilo para [SliverAppBar] com o mesmo fundo verde.
abstract final class BvForestSliverAppBar {
  static const Color barColor = Colors.transparent;

  static Widget background({bool showIconWatermark = false}) {
    return ForestHeroBackground(showIconWatermark: showIconWatermark);
  }
}
