package com.tradearoundworld.trade_around_the_world

import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val musicChannel = "trade_around_the_world/game_music"
    private val updateChannel = "trade_around_the_world/app_update"
    private var gameMusicPlayer: MediaPlayer? = null
    private var resultMusicPlayer: MediaPlayer? = null
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
                resultMusicPlayer?.setVolume(1f, 1f)
                if (resultMusicPlayer != null) {
                    try {
                        if (resultMusicPlayer?.isPlaying == false) resultMusicPlayer?.start()
                    } catch (_: IllegalStateException) {
                        releaseResultPlayer()
                    }
                } else if (musicRequested && gameMusicPlayer?.isPlaying == false) {
                    startPlayer()
                }
            }
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                gameMusicPlayer?.pause()
                resultMusicPlayer?.pause()
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
                    "winner" -> {
                        playResultMusic(R.raw.winner_celebration)
                        result.success(null)
                    }
                    "loser" -> {
                        playResultMusic(R.raw.loser_defeat)
                        result.success(null)
                    }
                    "stop" -> {
                        stopGameMusic()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, updateChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_path", "مسیر فایل بروزرسانی نامعتبر است.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            openPackageInstaller(File(path))
                            result.success(null)
                        } catch (error: Exception) {
                            result.error(
                                "installer_unavailable",
                                error.message ?: "باز کردن نصب کننده اندروید ممکن نشد.",
                                null,
                            )
                        }
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
        releaseResultPlayer()
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

    private fun playResultMusic(soundResource: Int) {
        if (resultMusicPlayer != null) return
        releasePlayer()
        requestMusicAudioFocus()
        val player = try {
            MediaPlayer.create(
                applicationContext,
                soundResource,
                musicAttributes,
                AudioManager.AUDIO_SESSION_ID_GENERATE,
            )
        } catch (_: RuntimeException) {
            null
        }
        if (player == null) {
            if (musicRequested) {
                createPlayer()
                startPlayer()
            }
            return
        }
        resultMusicPlayer = player.apply {
            isLooping = false
            setVolume(1f, 1f)
            setOnCompletionListener { completedPlayer ->
                if (resultMusicPlayer === completedPlayer) {
                    releaseResultPlayer()
                    if (musicRequested) {
                        createPlayer()
                        startPlayer()
                    }
                }
            }
            setOnErrorListener { failedPlayer, _, _ ->
                if (resultMusicPlayer === failedPlayer) {
                    releaseResultPlayer()
                    if (musicRequested) {
                        createPlayer()
                        startPlayer()
                    }
                }
                true
            }
        }
        try {
            player.start()
        } catch (_: IllegalStateException) {
            releaseResultPlayer()
            if (musicRequested) {
                createPlayer()
                startPlayer()
            }
        }
    }

    private fun releaseResultPlayer() {
        resultMusicPlayer?.let { player ->
            player.setOnCompletionListener(null)
            player.setOnErrorListener(null)
            try {
                if (player.isPlaying) player.stop()
            } catch (_: IllegalStateException) {
                // The player may already be in an error state.
            }
            player.release()
        }
        resultMusicPlayer = null
    }

    private fun openPackageInstaller(apkFile: File) {
        if (!apkFile.isFile || apkFile.length() == 0L) {
            throw IllegalArgumentException("فایل بروزرسانی پیدا نشد.")
        }
        val apkUri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            apkFile,
        )
        val installIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(installIntent)
    }
}
