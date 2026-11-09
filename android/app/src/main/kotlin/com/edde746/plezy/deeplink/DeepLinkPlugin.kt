package com.edde746.plezy.deeplink

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Hands every `plezy:` link to Dart unchanged. The link grammar lives only in
 * `lib/services/deep_links/deep_link.dart`, so nothing here reads hosts or
 * query parameters.
 *
 * Also hands over videos other apps open with Plezy ("Open with"): a separate
 * message, so a `plezy:` link from a web page can never name media to play.
 */
class DeepLinkPlugin :
  FlutterPlugin,
  MethodChannel.MethodCallHandler {
  companion object {
    private const val METHOD_CHANNEL = "com.plezy/deep_link"
    private const val SCHEME = "plezy"

    // One slot, latest link wins. It lives here rather than on the instance so a
    // link Dart has not accepted yet survives the engine being re-created.
    private var retainedLink: String? = null
    private var retainedMedia: Map<String, String?>? = null

    private val MEDIA_SCHEMES = setOf("content", "file", "http", "https")

    /** A video another app asked Plezy to play: its URI and display name. */
    fun mediaFrom(context: Context, intent: Intent?): Map<String, String?>? {
      if (intent?.action != Intent.ACTION_VIEW) return null
      val data = intent.data ?: return null
      if (data.scheme?.lowercase() !in MEDIA_SCHEMES) return null
      val type = intent.type ?: runCatching { context.contentResolver.getType(data) }.getOrNull()
      if (type?.lowercase()?.startsWith("video/") != true) return null
      return mapOf("uri" to data.toString(), "title" to displayName(context, data))
    }

    private fun displayName(context: Context, uri: Uri): String? {
      if (uri.scheme == "content") {
        runCatching {
          context.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst() && !c.isNull(0)) return c.getString(0)
          }
        }
      }
      return uri.lastPathSegment
    }

    fun linkFrom(intent: Intent?): String? {
      val data = intent?.data ?: return null
      if (!SCHEME.equals(data.scheme, ignoreCase = true)) return null
      return data.toString()
    }
  }

  private var methodChannel: MethodChannel? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL).also {
      it.setMethodCallHandler(this)
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    methodChannel?.setMethodCallHandler(null)
    methodChannel = null
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "getInitialLink" -> {
        val url = retainedLink
        retainedLink = null
        result.success(url)
      }
      "getInitialMedia" -> {
        val media = retainedMedia
        retainedMedia = null
        result.success(media)
      }
      else -> result.notImplemented()
    }
  }

  fun notifyMedia(media: Map<String, String?>) {
    retainedMedia = media
    val channel = methodChannel ?: return
    channel.invokeMethod(
      "onOpenMedia",
      media,
      object : MethodChannel.Result {
        override fun success(result: Any?) {
          if (result == true && retainedMedia == media) retainedMedia = null
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}

        override fun notImplemented() {}
      }
    )
  }

  fun notifyLink(url: String) {
    retainedLink = url
    // Not attached to an engine yet: Dart collects the link through getInitialLink.
    val channel = methodChannel ?: return
    channel.invokeMethod(
      "onLink",
      mapOf("url" to url),
      object : MethodChannel.Result {
        // Dart answers true only once it took the link; until then it stays
        // retained for getInitialLink. Clearing it here keeps the next startup
        // path (profile switch, sign-in, a re-created engine) from replaying it,
        // and the equality check keeps a late answer for an older link from
        // dropping a newer one.
        override fun success(result: Any?) {
          if (result == true && retainedLink == url) retainedLink = null
        }

        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}

        override fun notImplemented() {}
      }
    )
  }
}
