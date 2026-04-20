import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider((ref) => AudioService());

class AudioService {
  Future<void> _playAsset(String path) async {
    final player = AudioPlayer();
    try {
      // Auto-dispose when finished to prevent memory leaks
      player.onPlayerComplete.listen((_) => player.dispose());
      player.play(AssetSource(path));
    } catch (e) {
      // ignore: avoid_print
      print('Error playing audio: $e');
      player.dispose();
    }
  }

  Future<void> playTestCorrect() => _playAsset('sesler/coktan-secmeli-dogru.mp3');
  Future<void> playTestWrong() => _playAsset('sesler/coktan-secmeli-yanlis.mp3');
  
  Future<void> playSpellingCorrect() => _playAsset('sesler/yazim-dogru.mp3');
  Future<void> playSpellingWrong() => _playAsset('sesler/yazim-yanlis.mp3');
  
  Future<void> playCardFlip() => _playAsset('sesler/kart-cevirme.mp3');
  Future<void> playCardUp() => _playAsset('sesler/kartlar-yukari.mp3');
  Future<void> playCardDown() => _playAsset('sesler/kartlar-asagi.mp3');

  void dispose() {
    // No global player to dispose anymore
  }
}
