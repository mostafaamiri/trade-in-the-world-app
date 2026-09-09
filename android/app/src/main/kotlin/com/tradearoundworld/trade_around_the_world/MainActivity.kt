package com.tradearoundworld.trade_around_the_world

import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val musicChannel = "trade_around_the_world/game_music"
    private val soundtrackResources = intArrayOf(
        R.raw.game_track_1,
        R.raw.game_track_2,
        R.raw.game_track_3,
        R.raw.game_track_4,
    )

    private var gameMusicPlayer: MediaPlayer? = null
    private var soundtrackIndex = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, musicChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        startGameMusic()
                        result.success(null)
                    }
                    "stop" -> {
                        stopGameMusic()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        stopGameMusic()
        super.onDestroy()
    }

    private fun startGameMusic() {
        if (gameMusicPlayer?.isPlaying == true) return
        playTrack(soundtrackIndex)
    }

    private fun playTrack(index: Int) {
        stopGameMusic()
        soundtrackIndex = index
        gameMusicPlayer = MediaPlayer.create(applicationContext, soundtrackResources[index])?.apply {
            setOnCompletionListener { completedPlayer ->
                if (gameMusicPlayer == completedPlayer) {
                    gameMusicPlayer = null
                    completedPlayer.release()
                    playTrack((soundtrackIndex + 1) % soundtrackResources.size)
                }
            }
            start()
        }
    }

    private fun stopGameMusic() {
        gameMusicPlayer?.let { player ->
            player.setOnCompletionListener(null)
            if (player.isPlaying) player.stop()
            player.release()
        }
        gameMusicPlayer = null
    }
}
