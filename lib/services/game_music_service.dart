import 'dart:async';

import 'package:flutter/services.dart';

class GameMusicService {
  GameMusicService._();

  static const _channel = MethodChannel('trade_around_the_world/game_music');
  static int _owners = 0;
  static final Set<String> _winnerMatchesPlayed = <String>{};
  static final Set<String> _loserMatchesPlayed = <String>{};

  static Future<void> acquire() async {
    _owners++;
    try {
      await _channel.invokeMethod<void>('start');
    } catch (_) {
      // Audio playback must never block access to the game.
    }
  }

  static Future<void> release() async {
    if (_owners == 0) return;
    _owners--;
    if (_owners != 0) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (_) {
      // Stopping audio is best effort during route transitions.
    }
  }

  static Future<void> playWinner(String matchId) async {
    if (!_winnerMatchesPlayed.add(matchId)) return;
    try {
      await _channel.invokeMethod<void>('winner');
    } catch (_) {
      _winnerMatchesPlayed.remove(matchId);
    }
  }

  static Future<void> playLoser(String matchId) async {
    if (!_loserMatchesPlayed.add(matchId)) return;
    try {
      await _channel.invokeMethod<void>('loser');
    } catch (_) {
      _loserMatchesPlayed.remove(matchId);
    }
  }
}
