import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 효과음 종류.
enum Sfx {
  /// 병을 집을 때.
  pick('audio/pick.wav'),

  /// 쪼르륵. 붓는 동안 나고, 다 부으면 멈춘다.
  pour('audio/pour.wav'),

  /// 한 판을 다 맞췄을 때.
  clear('audio/clear.wav'),

  /// 부을 수 없는 곳에 부으려 했을 때.
  wrong('audio/wrong.wav');

  const Sfx(this.asset);

  final String asset;
}

/// 효과음 재생기.
///
/// **BGM은 없다.** 오래 하면 피로해지기 때문이다.
/// 소리는 전부 짧고, 설정에서 통째로 끌 수 있다.
///
/// 소리가 안 나는 것보다 게임이 멈추는 게 훨씬 나쁘므로,
/// 재생 실패는 모두 삼키고 조용히 넘어간다.
class AudioService {
  AudioService({this.enabled = true});

  /// 소리를 낼지. 설정에서 끄면 false가 된다.
  bool enabled;

  /// 짧은 소리들. 겹쳐 나도 되도록 붓는 소리와 따로 둔다.
  final AudioPlayer _oneShot = AudioPlayer(playerId: 'sfx_oneshot');

  /// 쪼르륵 전용. 도중에 멈춰야 하므로 재생기를 따로 가진다.
  final AudioPlayer _pour = AudioPlayer(playerId: 'sfx_pour');

  bool _ready = false;

  /// 재생기를 준비한다. 실패해도 게임은 그대로 돌아간다.
  Future<void> init() async {
    try {
      await _oneShot.setReleaseMode(ReleaseMode.stop);
      await _pour.setReleaseMode(ReleaseMode.stop);
      // 효과음은 다른 앱의 소리를 끊지 않아야 한다.
      await _oneShot.setPlayerMode(PlayerMode.lowLatency);
      _ready = true;
    } catch (e) {
      debugPrint('효과음을 준비하지 못했습니다. 소리 없이 진행합니다: $e');
      _ready = false;
    }
  }

  Future<void> play(Sfx sfx) async {
    if (!enabled || !_ready) return;
    if (sfx == Sfx.pour) return playPour();
    try {
      await _oneShot.stop();
      await _oneShot.play(AssetSource(sfx.asset));
    } catch (_) {
      // 소리 하나 못 낸 것으로 게임을 멈추지 않는다.
    }
  }

  /// 쪼르륵을 시작한다. [stopPour]를 부를 때까지 계속 난다.
  ///
  /// 붓는 양에 따라 길이가 달라지는 것을 이렇게 처리한다.
  /// 1칸이면 짧게, 8칸이면 길게 — 파일을 여러 개 두는 대신
  /// 넉넉히 긴 소리 하나를 필요한 만큼만 재생한다.
  Future<void> playPour() async {
    if (!enabled || !_ready) return;
    try {
      await _pour.stop();
      await _pour.play(AssetSource(Sfx.pour.asset));
    } catch (_) {}
  }

  Future<void> stopPour() async {
    if (!_ready) return;
    try {
      await _pour.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    try {
      await _oneShot.dispose();
      await _pour.dispose();
    } catch (_) {}
  }
}
