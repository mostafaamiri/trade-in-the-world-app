package com.tradearoundworld.trade_around_the_world

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
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
    private var musicRequested = false
    private var audioFocusRequest: AudioFocusRequest? = null

    private val audioManager by lazy {
        getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    private val musicAttributes = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_GAME)
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
        if (!requestMusicAudioFocus()) return
        if (gameMusicPlayer?.isPlaying == true) return
        if (gameMusicPlayer != null) {
            gameMusicPlayer?.start()
            return
        }
        playTrack(soundtrackIndex)
    }

    private fun playTrack(index: Int) {
        releaseMusicPlayer()
        soundtrackIndex = index
        gameMusicPlayer = MediaPlayer.create(
            applicationContext,
            soundtrackResources[index],
            musicAttributes,
            AudioManager.AUDIO_SESSION_ID_GENERATE,
        )?.apply {
            setOnCompletionListener { completedPlayer ->
                if (gameMusicPlayer === completedPlayer && musicRequested) {
                    releaseMusicPlayer()
                    playTrack((soundtrackIndex + 1) % soundtrackResources.size)
                }
            }
            setOnErrorListener { failedPlayer, _, _ ->
                if (gameMusicPlayer === failedPlayer && musicRequested) {
                    releaseMusicPlayer()
                    playTrack((soundtrackIndex + 1) % soundtrackResources.size)
                }
                true
            }
            setVolume(1f, 1f)
            start()
        }
    }

    private fun stopGameMusic() {
        musicRequested = false
        releaseMusicPlayer()
        audioFocusRequest?.let { audioManager.abandonAudioFocusRequest(it) }
    }

    private fun requestMusicAudioFocus(): Boolean {
        val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
            .setAudioAttributes(musicAttributes)
            .setOnAudioFocusChangeListener(audioFocusListener)
            .build()
        audioFocusRequest = request
        return audioManager.requestAudioFocus(request) == AudioManager.AUDIOFOCUS_REQUEST_GRANTED
    }

    private fun releaseMusicPlayer() {
        gameMusicPlayer?.let { player ->
            player.setOnCompletionListener(null)
            player.setOnErrorListener(null)
            if (player.isPlaying) {
                player.stop()
            }
            player.release()
        }
        gameMusicPlayer = null
    }
}
