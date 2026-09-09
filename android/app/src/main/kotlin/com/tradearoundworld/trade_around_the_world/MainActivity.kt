package com.tradearoundworld.trade_around_the_world

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
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
    private var musicRequested = false
    private var audioFocusRequest: AudioFocusRequest? = null
    private val musicHandler = Handler(Looper.getMainLooper())
    private val musicRetry = object : Runnable {
        override fun run() {
            if (!musicRequested) return
            startGameMusic()
        }
    }

    private val audioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private val musicAttributes = AudioAttributes.Builder()
        // Music should follow the device's normal media volume and routing.
        .setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
        .build()

    private val audioFocusListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                gameMusicPlayer?.setVolume(1f, 1f)
                if (musicRequested && gameMusicPlayer?.isPlaying == false) {
                    gameMusicPlayer?.start()
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                gameMusicPlayer?.pause()
                scheduleMusicRetry()
            }
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

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus && musicRequested) startGameMusic()
    }

    private fun startGameMusic() {
        musicRequested = true
        // Focus is requested for correct system behaviour, but a temporary
        // denial must not permanently disable the soundtrack.
        if (!requestMusicAudioFocus()) scheduleMusicRetry()
        if (gameMusicPlayer?.isPlaying == true) {
            musicHandler.removeCallbacks(musicRetry)
            return
        }
        if (gameMusicPlayer != null) {
            try {
                gameMusicPlayer?.start()
                return
            } catch (_: IllegalStateException) {
                releaseMusicPlayer()
            }
        }
        playTrack(soundtrackIndex)
    }

    private fun playTrack(index: Int) {
        releaseMusicPlayer()
        soundtrackIndex = index
        val player = try {
            MediaPlayer.create(
                applicationContext,
                soundtrackResources[index],
                musicAttributes,
                AudioManager.AUDIO_SESSION_ID_GENERATE,
            )
        } catch (_: RuntimeException) {
            null
        }
        if (player == null) {
            scheduleMusicRetry()
            return
        }
        gameMusicPlayer = player
        player.setOnCompletionListener { completedPlayer ->
            if (gameMusicPlayer === completedPlayer && musicRequested) {
                releaseMusicPlayer()
                playTrack((soundtrackIndex + 1) % soundtrackResources.size)
            }
        }
        player.setOnErrorListener { failedPlayer, _, _ ->
            if (gameMusicPlayer === failedPlayer && musicRequested) {
                releaseMusicPlayer()
                playTrack((soundtrackIndex + 1) % soundtrackResources.size)
            }
            true
        }
        player.setVolume(1f, 1f)
        try {
            player.start()
            musicHandler.removeCallbacks(musicRetry)
        } catch (_: IllegalStateException) {
            releaseMusicPlayer()
            scheduleMusicRetry()
        }
    }

    private fun stopGameMusic() {
        musicRequested = false
        musicHandler.removeCallbacks(musicRetry)
        releaseMusicPlayer()
        audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
    }

    private fun scheduleMusicRetry() {
        if (!musicRequested) return
        musicHandler.removeCallbacks(musicRetry)
        musicHandler.postDelayed(musicRetry, 750L)
    }

    private fun requestMusicAudioFocus(): Boolean {
        val request = audioFocusRequest ?: AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(musicAttributes)
            .setOnAudioFocusChangeListener(audioFocusListener)
            .build()
            .also { audioFocusRequest = it }
        return audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun releaseMusicPlayer() {
        gameMusicPlayer?.let { player ->
            player.setOnCompletionListener(null)
            player.setOnErrorListener(null)
            try {
                if (player.isPlaying) player.stop()
            } catch (_: IllegalStateException) {
                // The player may already be in its error state.
            }
            player.release()
        }
        gameMusicPlayer = null
    }
}
