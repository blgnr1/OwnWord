import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final audioServiceProvider = Provider((ref) => AudioService.instance);

class AudioService {
  static final AudioService instance = AudioService._internal();
  final Map<String, AudioPlayer> _players = {};
  final FlutterTts _tts = FlutterTts();
  bool _ttsInitialized = false;

  AudioService._internal() {
    for (final sound in ['correct', 'wrong', 'spelling_correct', 'spelling_wrong', 'flip', 'up', 'down']) {
      _players[sound] = AudioPlayer();
    }
  }

  Future<void> init() async {
    await _initTts();
    try {
      await _players['correct']?.setSource(AssetSource('sesler/coktan-secmeli-dogru.mp3'));
      await _players['wrong']?.setSource(AssetSource('sesler/coktan-secmeli-yanlis.mp3'));
      await _players['spelling_correct']?.setSource(AssetSource('sesler/yazim-dogru.mp3'));
      await _players['spelling_wrong']?.setSource(AssetSource('sesler/yazim-yanlis.mp3'));
      await _players['flip']?.setSource(AssetSource('sesler/kart-cevirme.mp3'));
      await _players['up']?.setSource(AssetSource('sesler/kartlar-yukari.mp3'));
      await _players['down']?.setSource(AssetSource('sesler/kartlar-asagi.mp3'));
    } catch (e) {
      print('Error pre-setting audio sources: $e');
    }
  }

  Future<void> _initTts() async {
    if (_ttsInitialized) return;
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45); // Slightly adjusted for natural English clarity
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ttsInitialized = true;
    } catch (e) {
      print('Error initializing TTS: $e');
    }
  }

  Future<void> _playSound(String name, String fallbackPath) async {
    final player = _players[name];
    if (player != null) {
      try {
        await player.stop();
        await player.play(AssetSource(fallbackPath));
      } catch (e) {
        print('Error playing audio $name: $e');
      }
    }
  }

  Future<void> playTestCorrect() => _playSound('correct', 'sesler/coktan-secmeli-dogru.mp3');
  Future<void> playTestWrong() => _playSound('wrong', 'sesler/coktan-secmeli-yanlis.mp3');
  
  Future<void> playSpellingCorrect() => _playSound('spelling_correct', 'sesler/yazim-dogru.mp3');
  Future<void> playSpellingWrong() => _playSound('spelling_wrong', 'sesler/yazim-yanlis.mp3');
  
  Future<void> playCardFlip() => _playSound('flip', 'sesler/kart-cevirme.mp3');
  Future<void> playCardUp() => _playSound('up', 'sesler/kartlar-yukari.mp3');
  Future<void> playCardDown() => _playSound('down', 'sesler/kartlar-asagi.mp3');

  Future<void> speak(String text) async {
    try {
      await _tts.stop();
      // Force en-US language explicitly right before speaking
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45);
      await _tts.speak(text);
    } catch (e) {
      print('TTS speak error: $e');
    }
  }

  Future<void> stopTts() async {
    try {
      await _tts.stop();
    } catch (e) {
      print('TTS stop error: $e');
    }
  }

  void dispose() {
    for (final p in _players.values) {
      p.dispose();
    }
    _tts.stop();
  }
}
