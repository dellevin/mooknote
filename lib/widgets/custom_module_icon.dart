import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// 自定义分类模块图标：FontAwesome 纯色图标（DB 存 codePoint 字符串，
/// 兼容早期存 emoji 的数据——无法解析为 codePoint 时按 emoji 文本渲染）

/// 可供选择的 FontAwesome 图标（新增/重命名模块弹窗中上下滑动选择）
const kCustomModuleIcons = <IconData>[
  // 影音阅读
  FontAwesomeIcons.tv,
  FontAwesomeIcons.film,
  FontAwesomeIcons.clapperboard,
  FontAwesomeIcons.masksTheater,
  FontAwesomeIcons.video,
  FontAwesomeIcons.ticket,
  FontAwesomeIcons.headphones,
  FontAwesomeIcons.podcast,
  FontAwesomeIcons.music,
  FontAwesomeIcons.radio,
  FontAwesomeIcons.microphone,
  FontAwesomeIcons.guitar,
  FontAwesomeIcons.drum,
  FontAwesomeIcons.book,
  FontAwesomeIcons.bookOpen,
  FontAwesomeIcons.newspaper,
  FontAwesomeIcons.pen,
  // 游戏娱乐
  FontAwesomeIcons.gamepad,
  FontAwesomeIcons.chess,
  FontAwesomeIcons.puzzlePiece,
  FontAwesomeIcons.dice,
  FontAwesomeIcons.ghost,
  FontAwesomeIcons.robot,
  FontAwesomeIcons.trophy,
  FontAwesomeIcons.medal,
  FontAwesomeIcons.dumbbell,
  FontAwesomeIcons.futbol,
  FontAwesomeIcons.personRunning,
  // 图片创作
  FontAwesomeIcons.palette,
  FontAwesomeIcons.camera,
  FontAwesomeIcons.cameraRetro,
  FontAwesomeIcons.image,
  FontAwesomeIcons.images,
  // 出行自然
  FontAwesomeIcons.plane,
  FontAwesomeIcons.car,
  FontAwesomeIcons.bicycle,
  FontAwesomeIcons.rocket,
  FontAwesomeIcons.locationDot,
  FontAwesomeIcons.compass,
  FontAwesomeIcons.globe,
  FontAwesomeIcons.map,
  FontAwesomeIcons.mountain,
  FontAwesomeIcons.tree,
  FontAwesomeIcons.leaf,
  FontAwesomeIcons.sun,
  FontAwesomeIcons.moon,
  FontAwesomeIcons.cloud,
  FontAwesomeIcons.snowflake,
  FontAwesomeIcons.fire,
  FontAwesomeIcons.bolt,
  FontAwesomeIcons.umbrella,
  // 动物
  FontAwesomeIcons.paw,
  FontAwesomeIcons.cat,
  FontAwesomeIcons.dog,
  FontAwesomeIcons.fish,
  // 美食
  FontAwesomeIcons.mugHot,
  FontAwesomeIcons.mugSaucer,
  FontAwesomeIcons.utensils,
  FontAwesomeIcons.pizzaSlice,
  FontAwesomeIcons.burger,
  FontAwesomeIcons.appleWhole,
  FontAwesomeIcons.cakeCandles,
  FontAwesomeIcons.wineGlass,
  FontAwesomeIcons.beerMugEmpty,
  // 生活
  FontAwesomeIcons.house,
  FontAwesomeIcons.couch,
  FontAwesomeIcons.bed,
  FontAwesomeIcons.shirt,
  FontAwesomeIcons.gift,
  FontAwesomeIcons.cartShopping,
  FontAwesomeIcons.briefcase,
  FontAwesomeIcons.graduationCap,
  FontAwesomeIcons.baby,
  FontAwesomeIcons.child,
  FontAwesomeIcons.person,
  // 物件
  FontAwesomeIcons.laptop,
  FontAwesomeIcons.mobile,
  FontAwesomeIcons.keyboard,
  FontAwesomeIcons.headset,
  FontAwesomeIcons.noteSticky,
  FontAwesomeIcons.envelope,
  FontAwesomeIcons.comment,
  FontAwesomeIcons.bell,
  FontAwesomeIcons.calendar,
  FontAwesomeIcons.clock,
  FontAwesomeIcons.binoculars,
  FontAwesomeIcons.glasses,
  FontAwesomeIcons.lightbulb,
  FontAwesomeIcons.magnet,
  FontAwesomeIcons.key,
  FontAwesomeIcons.shield,
  // 标记
  FontAwesomeIcons.star,
  FontAwesomeIcons.heart,
  FontAwesomeIcons.bookmark,
  FontAwesomeIcons.flag,
  FontAwesomeIcons.tag,
  FontAwesomeIcons.folder,
  FontAwesomeIcons.box,
  FontAwesomeIcons.crown,
  FontAwesomeIcons.gem,
  FontAwesomeIcons.wandSparkles,
  FontAwesomeIcons.hatWizard,
  FontAwesomeIcons.mask,
  FontAwesomeIcons.faceSmile,
  FontAwesomeIcons.thumbsUp,
];

/// 把 DB 中的 icon 字符串解析为 FontAwesome IconData；非 codePoint（旧 emoji 数据）返回 null
/// 注意：必须返回 kCustomModuleIcons 中的常量实例——运行时 new IconData(codePoint, ...)
/// 是非常量调用，会导致 release 构建的图标 tree-shake 失败
IconData? customModuleIconData(String icon) {
  if (icon.isEmpty) return null;
  final codePoint = int.tryParse(icon);
  if (codePoint == null) return null;
  for (final iconData in kCustomModuleIcons) {
    if (iconData.codePoint == codePoint) return iconData;
  }
  return null;
}

/// 渲染模块图标：FontAwesome 优先，旧 emoji 数据按文本渲染，空值显示兜底图标
Widget buildCustomModuleIcon(
  String icon, {
  double size = 18,
  Color? color,
  IconData fallback = Icons.dashboard_customize_outlined,
}) {
  final faIcon = customModuleIconData(icon);
  if (faIcon != null) return Icon(faIcon, size: size, color: color);
  if (icon.isNotEmpty) return Text(icon, style: TextStyle(fontSize: size));
  return Icon(fallback, size: size, color: color);
}
