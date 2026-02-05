import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
}

class AppRadii {
  const AppRadii._();

  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 18;
  static const double xxl = 22;

  static const double pill = 999;
}

class AppSizes {
  const AppSizes._();

  static const double maxContentWidth = 1120;

  static const double buttonHeightSm = 44;
  static const double buttonHeight = 48;
  static const double buttonHeightLg = 56;

  static const double iconButtonSize = 44;
}

class AppMotion {
  const AppMotion._();

  static const Duration fast = Duration(milliseconds: 120);
  static const Duration normal = Duration(milliseconds: 180);
  static const Duration slow = Duration(milliseconds: 260);

  static const Curve standardCurve = Curves.easeOutCubic;
}

class AppShadows {
  const AppShadows._();

  static const List<BoxShadow> softCard = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 8)),
  ];
}
