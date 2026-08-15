import 'package:flutter/material.dart';

/// 액체 색 팔레트.
///
/// 색 인덱스(로직이 쓰는 정수)를 실제 화면 색으로 바꾼다.
/// 로직은 색을 정수로만 다루고 실제 색상은 전적으로 여기서 정한다.
class Palette {
  /// 최고 난이도에서 쓰는 색 가짓수와 같아야 한다.
  /// (`LevelConfig.maxColors`와 반드시 일치해야 하며, 테스트가 이를 확인한다.)
  static const int maxColors = 15;

  /// 15색. 서로 최대한 헷갈리지 않도록 색상(hue)과 밝기를 함께 벌려 놓았다.
  ///
  /// 비슷한 색을 나란히 두면 퍼즐이 아니라 시력 검사가 된다.
  /// 특히 빨강–주황, 파랑–남색처럼 붙기 쉬운 짝은 밝기를 다르게 줬다.
  ///
  /// **15가지가 실질적인 한계다.** 이보다 늘리면 색끼리 붙어서
  /// 눈이 좋은 사람에게만 풀리는 게임이 된다. 난이도는 색이 아니라
  /// 병 깊이로 올린다.
  static const List<Color> liquids = [
    Color(0xFFE53935), // 빨강
    Color(0xFF1E88E5), // 파랑
    Color(0xFF43A047), // 초록
    Color(0xFFFDD835), // 노랑
    Color(0xFF8E24AA), // 보라
    Color(0xFFFB8C00), // 주황
    Color(0xFF00ACC1), // 청록
    Color(0xFFEC407A), // 분홍
    Color(0xFF6D4C41), // 갈색
    Color(0xFFAEEA00), // 연두
    Color(0xFF283593), // 남색
    Color(0xFFB0BEC5), // 밝은 회색
    Color(0xFF00695C), // 짙은 청록
    Color(0xFFFF8A80), // 살구
    Color(0xFF546E7A), // 짙은 회청색
  ];

  /// 색약 모드에서 각 색 위에 함께 표시할 기호.
  ///
  /// 설정에서 켜는 **옵션이며 기본값은 꺼짐**이다.
  /// 색만으로 구분이 어려울 때 모양이 보조해 준다.
  static const List<String> symbols = [
    '●', '▲', '■', '★', '◆', '♥', '✚', '▼',
    '♦', '◐', '✦', '◼', '✜', '◒', '⬟',
  ];

  static Color liquid(int colorIndex) => liquids[colorIndex % liquids.length];

  /// 폴더(챕터)마다 다른 색을 준다.
  ///
  /// 액체 팔레트를 그대로 쓰되 순서를 흩어 놓았다. 이웃한 폴더가
  /// 비슷한 색으로 나란히 놓이면 폴더를 구분하는 의미가 없어진다.
  static Color chapterAccent(int index) =>
      liquids[(index * 7) % liquids.length];

  static String symbol(int colorIndex) => symbols[colorIndex % symbols.length];

  /// 액체 색 위에 글자를 얹을 때 읽히는 색(검정 또는 흰색)을 고른다.
  ///
  /// 노랑 위의 흰 글자처럼 안 보이는 조합을 막는다.
  static Color onLiquid(int colorIndex) =>
      liquid(colorIndex).computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
}
