import 'package:bottlebottle/logic/generator.dart';
import 'package:bottlebottle/logic/level_config.dart';
void main(){
  // 앱이 켜질 때 저장된 레벨을 연다. 501~700 전 구간을 훑어 멈추는 곳을 찾는다.
  for(var lv=501; lv<=700; lv++){
    final sw=Stopwatch()..start();
    try{
      LevelGenerator.generate(lv);
      sw.stop();
      if(sw.elapsedMilliseconds>1500){
        final c=LevelConfig.forLevel(lv);
        print('Lv$lv 느림 ${sw.elapsedMilliseconds}ms  색${c.colorCount} 높이${c.bottleCapacities}');
      }
    }catch(e){
      sw.stop();
      final c=LevelConfig.forLevel(lv);
      print('Lv$lv 예외! ${sw.elapsedMilliseconds}ms  색${c.colorCount} 병${c.bottleCount}  $e');
    }
  }
  print('검사 끝');
}
