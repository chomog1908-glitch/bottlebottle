import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../logic/achievements.dart';
import '../model/move.dart';

/// 저장해 둔 판.
class SavedGame {
  final int level;

  /// 지금까지 둔 수. `[from, to]` 쌍의 목록이다.
  final List<List<int>> moves;

  const SavedGame({required this.level, required this.moves});
}

/// 진행도와 설정을 기기에 저장한다.
///
/// **저장 형식이 아주 작다.** 레벨 번호와 둔 수 목록만 남긴다.
/// 레벨은 번호만 알면 똑같이 다시 만들어지므로(생성기가 결정적이다),
/// 그 위에 둔 수를 순서대로 다시 두면 보드가 정확히 복원된다.
/// 되돌리기 기록과 빈 병 사용 기록까지 통째로 살아나는 것은 덤이다.
///
/// 병의 내용물을 통째로 저장하지 않는 이유이기도 하다. 그렇게 하면
/// 저장된 보드와 되돌리기 기록이 따로 놀아, 복원 후 되돌리기가 깨진다.
class Storage {
  static const String _keySave = 'saved_game_v1';
  static const String _keyMaxLevel = 'max_level_v1';
  static const String _keyShowSymbols = 'show_symbols_v1';
  static const String _keyCleared = 'cleared_levels_v1';
  static const String _keyStats = 'play_stats_v1';
  static const String _keyAchieved = 'achievement_dates_v1';
  static const String _keySound = 'sound_on_v1';
  static const String _keyLargeText = 'large_text_v1';
  static const String _keyTheme = 'theme_mode_v1';
  static const String _keySeenNotes = 'seen_rule_notes_v1';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  /// 지금 판을 저장한다. 수를 둘 때마다 호출해도 될 만큼 가볍다.
  Future<void> saveGame(int level, List<Move> moves) async {
    final data = jsonEncode({
      'level': level,
      'moves': [for (final m in moves) [m.from, m.to]],
    });
    (await _prefs).setString(_keySave, data);
  }

  /// 저장해 둔 판을 불러온다. 없거나 형식이 깨졌으면 null.
  ///
  /// 저장 파일이 손상돼도 게임이 죽으면 안 된다. 못 읽으면 조용히 새 판으로 시작한다.
  Future<SavedGame?> loadGame() async {
    final raw = (await _prefs).getString(_keySave);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final level = map['level'] as int;
      final moves = [
        for (final m in (map['moves'] as List))
          [(m as List)[0] as int, m[1] as int],
      ];
      return SavedGame(level: level, moves: moves);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearGame() async => (await _prefs).remove(_keySave);

  /// 지금까지 도달한 최고 레벨. 통계와 레벨 선택에 쓴다.
  Future<int> loadMaxLevel() async => (await _prefs).getInt(_keyMaxLevel) ?? 1;

  Future<void> saveMaxLevel(int level) async {
    final p = await _prefs;
    if (level > (p.getInt(_keyMaxLevel) ?? 1)) p.setInt(_keyMaxLevel, level);
  }

  /// 클리어한 레벨 번호들.
  ///
  /// 폴더 화면에서 어디까지 했는지 표시하는 데 쓴다.
  /// **잠금에는 쓰지 않는다.** 이 게임은 어떤 레벨도 막지 않는다.
  Future<Set<int>> loadClearedLevels() async {
    final raw = (await _prefs).getStringList(_keyCleared) ?? const [];
    return {
      for (final s in raw)
        if (int.tryParse(s) != null) int.parse(s),
    };
  }

  /// 레벨 하나를 클리어했다고 기록한다. 이미 있으면 아무 일도 하지 않는다.
  Future<void> addClearedLevel(int level) async {
    final p = await _prefs;
    final list = p.getStringList(_keyCleared) ?? <String>[];
    final key = '$level';
    if (list.contains(key)) return;
    list.add(key);
    await p.setStringList(_keyCleared, list);
  }

  /// 이미 보여준 규칙 안내의 이름들.
  ///
  /// 안내 카드는 **처음 한 번만** 뜬다. 매번 뜨면 잔소리가 되고, 잔소리는
  /// 읽지 않고 닫게 된다. 다시 보고 싶으면 화면 위 ⓘ 단추가 있다.
  Future<Set<String>> loadSeenRuleNotes() async =>
      ((await _prefs).getStringList(_keySeenNotes) ?? const []).toSet();

  /// 규칙 안내를 보여줬다고 기록한다.
  Future<void> markRuleNoteSeen(String id) async {
    final p = await _prefs;
    final list = p.getStringList(_keySeenNotes) ?? <String>[];
    if (list.contains(id)) return;
    list.add(id);
    await p.setStringList(_keySeenNotes, list);
  }

  /// 지금까지 쌓인 기록. 저장이 없거나 깨졌으면 빈 기록으로 시작한다.
  Future<PlayStats> loadStats() async {
    final raw = (await _prefs).getString(_keyStats);
    if (raw == null) return const PlayStats();
    try {
      return PlayStats.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // 기록이 깨졌다고 게임을 못 켜게 할 수는 없다. 조용히 처음부터 센다.
      return const PlayStats();
    }
  }

  Future<void> saveStats(PlayStats stats) async =>
      (await _prefs).setString(_keyStats, jsonEncode(stats.toJson()));

  /// 도전과제를 언제 얻었는지. `도전과제 id → YYYY-MM-DD`.
  ///
  /// 얻었는지 **여부**는 기록만 있으면 다시 계산되므로 저장하지 않아도 된다.
  /// 날짜만은 그때를 지나가면 알 길이 없어서 따로 남긴다.
  Future<Map<String, String>> loadAchievementDates() async {
    final raw = (await _prefs).getString(_keyAchieved);
    if (raw == null) return const {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final e in map.entries)
          if (e.value is String) e.key: e.value as String,
      };
    } catch (_) {
      return const {};
    }
  }

  /// 도전과제를 얻은 날짜를 적어 둔다. 이미 적힌 것은 덮어쓰지 않는다.
  Future<void> recordAchievements(Iterable<String> ids, String day) async {
    if (ids.isEmpty) return;
    final dates = {...await loadAchievementDates()};
    var changed = false;
    for (final id in ids) {
      if (dates.containsKey(id)) continue;
      dates[id] = day;
      changed = true;
    }
    if (changed) (await _prefs).setString(_keyAchieved, jsonEncode(dates));
  }

  // ── 내보내기 · 불러오기 ────────────────────────────────────────────────
  //
  // 이 앱은 스토어를 거치지 않고 APK로 전해 드리므로, 폰을 바꾸시면
  // 옮겨 담을 방법이 이것뿐이다. 인터넷을 쓰지 않는다는 원칙을 지키면서
  // 기록을 옮기려면 **글자로 뽑아 두는 것** 말고는 길이 없다.

  /// 저장된 모든 것을 글자 하나로 뽑는다.
  ///
  /// 설정까지 함께 담는다. 새 폰에서 큰 글씨를 다시 켜게 만들 이유가 없다.
  Future<String> exportAll() async {
    final p = await _prefs;
    return jsonEncode({
      'app': 'bottlebottle',
      // 형식이 바뀌면 이 번호를 올린다. 받는 쪽이 무엇을 읽을지 판단하는 근거다.
      'format': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'data': {
        _keySave: p.getString(_keySave),
        _keyMaxLevel: p.getInt(_keyMaxLevel),
        _keyCleared: p.getStringList(_keyCleared),
        _keyStats: p.getString(_keyStats),
        _keyAchieved: p.getString(_keyAchieved),
        _keyShowSymbols: p.getBool(_keyShowSymbols),
        _keySound: p.getBool(_keySound),
        _keyLargeText: p.getBool(_keyLargeText),
        _keyTheme: p.getString(_keyTheme),
        _keySeenNotes: p.getStringList(_keySeenNotes),
      },
    });
  }

  /// 뽑아 둔 글자를 도로 불러온다.
  ///
  /// **읽을 수 있을 때만 덮어쓴다.** 형식이 아니거나 값이 이상하면 아무것도
  /// 건드리지 않고 false를 준다. 잘못 붙여넣은 글자 때문에 지금 기록이
  /// 날아가는 것이 이 기능으로 일어날 수 있는 최악이기 때문이다.
  ///
  /// 담겨 있지 않은 항목은 그대로 둔다. 예전 형식으로 뽑은 백업에는
  /// 나중에 생긴 항목이 없을 수 있다.
  Future<bool> importAll(String raw) async {
    final Map<String, dynamic> data;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (map['app'] != 'bottlebottle') return false;
      data = map['data'] as Map<String, dynamic>;
    } catch (_) {
      return false;
    }

    final p = await _prefs;
    for (final entry in data.entries) {
      final value = entry.value;
      switch (value) {
        case null:
          break;
        case final String s:
          await p.setString(entry.key, s);
        case final int i:
          await p.setInt(entry.key, i);
        case final bool b:
          await p.setBool(entry.key, b);
        case final List<dynamic> list:
          await p.setStringList(entry.key, [
            for (final e in list)
              if (e is String) e,
          ]);
        default:
          // 모르는 모양은 조용히 넘긴다. 하나 때문에 나머지를 포기할 이유가 없다.
          break;
      }
    }
    return true;
  }

  /// 색약 모드(색 위 기호 표시). **기본값은 꺼짐.**
  Future<bool> loadShowSymbols() async =>
      (await _prefs).getBool(_keyShowSymbols) ?? false;

  Future<void> saveShowSymbols(bool value) async =>
      (await _prefs).setBool(_keyShowSymbols, value);

  /// 효과음. 기본값은 켜짐.
  Future<bool> loadSoundOn() async => (await _prefs).getBool(_keySound) ?? true;

  Future<void> saveSoundOn(bool value) async =>
      (await _prefs).setBool(_keySound, value);

  /// 큰 글씨 모드. 기본값은 꺼짐.
  Future<bool> loadLargeText() async =>
      (await _prefs).getBool(_keyLargeText) ?? false;

  Future<void> saveLargeText(bool value) async =>
      (await _prefs).setBool(_keyLargeText, value);

  /// 화면 밝기 모드. 기본값은 기기 설정 따라가기.
  Future<String> loadThemeMode() async =>
      (await _prefs).getString(_keyTheme) ?? 'system';

  Future<void> saveThemeMode(String value) async =>
      (await _prefs).setString(_keyTheme, value);
}
