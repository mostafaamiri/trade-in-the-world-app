package com.tradearoundworld.trade_around_the_world

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val musicChannel = "trade_around_the_world/game_music"
    private var gameMusicPlayer: MediaPlayer? = null
    private var musicRequested = false

    private val audioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private val musicAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()

    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                gameMusicPlayer?.setVolume(1f, 1f)
                if (musicRequested && gameMusicPlayer?.isPlaying == false) startPlayer()
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> gameMusicPlayer?.pause()
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK ->
                gameMusicPlayer?.setVolume(0.2f, 0.2f)
            AudioManager.AUDIOFOCUS_LOSS -> stopGameMusic()
        }
    }

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
        musicRequested = true
        requestMusicAudioFocus()
        if (gameMusicPlayer == null) createPlayer()
        startPlayer()
    }

    private fun createPlayer() {
        gameMusicPlayer = try {
            MediaPlayer.create(
                applicationContext,
                R.raw.game_track,
                musicAttributes,
                AudioManager.AUDIO_SESSION_ID_GENERATE,
            )?.apply {
                isLooping = true
                setVolume(1f, 1f)
                setOnErrorListener { failedPlayer, _, _ ->
                    if (gameMusicPlayer === failedPlayer && musicRequested) {
                        releasePlayer()
                        createPlayer()
                        startPlayer()
                    }
                    true
                }
            }
        } catch (_: RuntimeException) {
            null
        }
    }

    private fun startPlayer() {
        val player = gameMusicPlayer ?: return
        try {
            if (!player.isPlaying) player.start()
        } catch (_: IllegalStateException) {
            releasePlayer()
            if (musicRequested) {
                createPlayer()
                startPlayer()
            }
        }
    }

    private fun stopGameMusic() {
        musicRequested = false
        releasePlayer()
        @Suppress("DEPRECATION")
        audioManager.abandonAudioFocus(audioFocusListener)
    }

    private fun requestMusicAudioFocus(): Boolean {
        @Suppress("DEPRECATION")
        return audioManager.requestAudioFocus(
            audioFocusListener,
            AudioManager.STREAM_MUSIC,
            AudioManager.AUDIOFOCUS_GAIN,
        ) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun releasePlayer() {
        gameMusicPlayer?.let { player ->
            player.setOnErrorListener(null)
            try {
                if (player.isPlaying) player.stop()
            } catch (_: IllegalStateException) {
                // The player may already be in an error state.
            }
            player.release()
        }
        gameMusicPlayer = null
    }
}
