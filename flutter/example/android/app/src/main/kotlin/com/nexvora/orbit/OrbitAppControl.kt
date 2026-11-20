package com.nexvora.orbit

import android.app.ActivityManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.net.Uri
import android.os.Build
import android.provider.AlarmClock
import android.provider.MediaStore
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

/**
 * Native half of ORBIT's App Intelligence + Smart Actions.
 *
 * Everything here uses public, documented Android APIs only:
 *  - PackageManager.queryIntentActivities for launchable apps (visible through
 *    the <queries> MAIN/LAUNCHER declaration; QUERY_ALL_PACKAGES is NOT used).
 *  - Explicit, whitelisted intents (settings screens, camera, maps, timer, ...).
 *
 * There is no shell, no reflection into other apps and no accessibility
 * automation. Every action reports whether an activity could be resolved BEFORE
 * launch, and returns a precise status — it never reports success it cannot
 * know about (e.g. it can say "the Clock app was asked to start a timer", not
 * "the timer is running").
 */
class OrbitAppControl(private val context: Context, messenger: BinaryMessenger) {

    private val pm: PackageManager = context.packageManager

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                handle(call, result)
            } catch (t: Throwable) {
                result.error("native_error", t.message ?: t.javaClass.simpleName, null)
            }
        }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "listApps" -> result.success(listApps())
            "getIcon" -> {
                val pkg = call.argument<String>("package") ?: return result.error("arg", "package", null)
                val size = call.argument<Int>("size") ?: 96
                result.success(iconPng(pkg, size))
            }
            "launchApp" -> {
                val pkg = call.argument<String>("package") ?: return result.error("arg", "package", null)
                result.success(launchApp(pkg))
            }
            "supportedIntents" -> {
                val pkg = call.argument<String>("package") ?: return result.error("arg", "package", null)
                result.success(supportedIntents(pkg))
            }
            "findHandlers" -> {
                val kind = call.argument<String>("kind") ?: return result.error("arg", "kind", null)
                result.success(findHandlers(kind))
            }
            "perform" -> {
                val kind = call.argument<String>("kind") ?: return result.error("arg", "kind", null)
                @Suppress("UNCHECKED_CAST")
                val args = (call.argument<Map<String, Any?>>("args")) ?: emptyMap()
                result.success(perform(kind, args))
            }
            "deviceInfo" -> result.success(deviceInfo())
            else -> result.notImplemented()
        }
    }

    // ── App discovery ────────────────────────────────────────────────────────

    private fun launcherIntent(): Intent =
        Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)

    private fun listApps(): List<Map<String, Any?>> {
        val infos = pm.queryIntentActivities(launcherIntent(), 0)
        val byPkg = LinkedHashMap<String, MutableList<ResolveInfo>>()
        for (ri in infos) byPkg.getOrPut(ri.activityInfo.packageName) { mutableListOf() }.add(ri)
        return byPkg.map { (pkg, ris) ->
            val ai = ris.first().activityInfo.applicationInfo
            val pi = try { pm.getPackageInfo(pkg, 0) } catch (_: Throwable) { null }
            mapOf(
                "package" to pkg,
                "label" to ris.first().loadLabel(pm).toString(),
                "activities" to ris.map { it.activityInfo.name },
                "system" to ((ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0),
                "category" to categoryName(ai),
                "versionName" to pi?.versionName,
                "installTime" to pi?.firstInstallTime,
                "updateTime" to pi?.lastUpdateTime,
            )
        }.sortedBy { (it["label"] as String).lowercase() }
    }

    private fun categoryName(ai: ApplicationInfo): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return "undefined"
        return when (ai.category) {
            ApplicationInfo.CATEGORY_AUDIO -> "audio"
            ApplicationInfo.CATEGORY_VIDEO -> "video"
            ApplicationInfo.CATEGORY_IMAGE -> "image"
            ApplicationInfo.CATEGORY_SOCIAL -> "social"
            ApplicationInfo.CATEGORY_NEWS -> "news"
            ApplicationInfo.CATEGORY_MAPS -> "maps"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "productivity"
            ApplicationInfo.CATEGORY_GAME -> "game"
            else -> "undefined"
        }
    }

    private fun iconPng(pkg: String, size: Int): ByteArray? {
        return try {
            val d = pm.getApplicationIcon(pkg)
            val bmp = if (d is BitmapDrawable && d.bitmap != null) {
                Bitmap.createScaledBitmap(d.bitmap, size, size, true)
            } else {
                val b = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
                val c = Canvas(b)
                d.setBounds(0, 0, size, size)
                d.draw(c)
                b
            }
            ByteArrayOutputStream().also { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }.toByteArray()
        } catch (_: Throwable) {
            null
        }
    }

    private fun launchApp(pkg: String): Map<String, Any?> {
        val intent = pm.getLaunchIntentForPackage(pkg)
            ?: return status(false, "no_launch_activity", "$pkg has no launchable activity visible to ORBIT.")
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return start(intent, "Asked Android to open ${labelOf(pkg)}.")
    }

    private fun labelOf(pkg: String): String = try {
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (_: Throwable) { pkg }

    // ── Capability probing (public intents only) ─────────────────────────────

    /** Probe intents used to describe what an app can handle. */
    private fun probes(): Map<String, Intent> = linkedMapOf(
        "view_pdf" to Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse("content://probe/a.pdf"), "application/pdf"),
        "view_web" to Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com")),
        "view_image" to Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse("content://probe/a.jpg"), "image/*"),
        "play_audio" to Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse("content://probe/a.mp3"), "audio/*"),
        "play_video" to Intent(Intent.ACTION_VIEW).setDataAndType(Uri.parse("content://probe/a.mp4"), "video/*"),
        "share_text" to Intent(Intent.ACTION_SEND).setType("text/plain"),
        "share_image" to Intent(Intent.ACTION_SEND).setType("image/*"),
        "dial" to Intent(Intent.ACTION_DIAL, Uri.parse("tel:123")),
        "compose_email" to Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:a@b.c")),
        "compose_sms" to Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:123")),
        "map_geo" to Intent(Intent.ACTION_VIEW, Uri.parse("geo:0,0?q=probe")),
        "set_timer" to Intent(AlarmClock.ACTION_SET_TIMER),
        "set_alarm" to Intent(AlarmClock.ACTION_SET_ALARM),
        "camera" to Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA),
        "web_search" to Intent(Intent.ACTION_WEB_SEARCH),
        "edit_text" to Intent(Intent.ACTION_EDIT).setType("text/plain"),
    )

    private fun resolve(intent: Intent): List<ResolveInfo> =
        pm.queryIntentActivities(intent, PackageManager.MATCH_DEFAULT_ONLY)

    private fun supportedIntents(pkg: String): List<String> =
        probes().filter { (_, i) -> resolve(i).any { it.activityInfo.packageName == pkg } }.keys.toList()

    private fun findHandlers(kind: String): List<Map<String, Any?>> {
        val probe = probes()[kind] ?: return emptyList()
        return resolve(probe).map { it.activityInfo.packageName }.distinct()
            .filter { it != context.packageName }
            .map { mapOf("package" to it, "label" to labelOf(it)) }
    }

    // ── Typed, whitelisted actions ───────────────────────────────────────────

    private val settingsWhitelist = mapOf(
        "wifi" to Settings.ACTION_WIFI_SETTINGS,
        "bluetooth" to Settings.ACTION_BLUETOOTH_SETTINGS,
        "display" to Settings.ACTION_DISPLAY_SETTINGS,
        "sound" to Settings.ACTION_SOUND_SETTINGS,
        "location" to Settings.ACTION_LOCATION_SOURCE_SETTINGS,
        "battery" to Intent.ACTION_POWER_USAGE_SUMMARY,
        "airplane" to Settings.ACTION_AIRPLANE_MODE_SETTINGS,
        "apps" to Settings.ACTION_APPLICATION_SETTINGS,
        "storage" to Settings.ACTION_INTERNAL_STORAGE_SETTINGS,
        "accessibility" to Settings.ACTION_ACCESSIBILITY_SETTINGS,
        "date" to Settings.ACTION_DATE_SETTINGS,
        "language" to Settings.ACTION_LOCALE_SETTINGS,
        "settings" to Settings.ACTION_SETTINGS,
    )

    private fun perform(kind: String, args: Map<String, Any?>): Map<String, Any?> {
        val intent: Intent
        val okMsg: String
        when (kind) {
            "settings" -> {
                val page = args["page"] as? String ?: "settings"
                val action = settingsWhitelist[page]
                    ?: return status(false, "unsupported", "Settings page '$page' is not supported.")
                intent = Intent(action); okMsg = "Asked Android to open the $page settings."
            }
            "camera" -> { intent = Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA); okMsg = "Asked Android to open the camera." }
            "map" -> {
                val q = (args["query"] as? String)?.trim().orEmpty()
                val uri = if (q.isEmpty()) "geo:0,0" else "geo:0,0?q=${Uri.encode(q)}"
                intent = Intent(Intent.ACTION_VIEW, Uri.parse(uri)); okMsg = "Asked a maps app to open ${if (q.isEmpty()) "the map" else "'$q'"}."
            }
            "timer" -> {
                val secs = (args["seconds"] as? Number)?.toInt()
                    ?: return status(false, "bad_args", "A timer needs a duration in seconds.")
                if (secs !in 1..86400) return status(false, "bad_args", "Timer must be between 1 second and 24 hours.")
                intent = Intent(AlarmClock.ACTION_SET_TIMER)
                    .putExtra(AlarmClock.EXTRA_LENGTH, secs)
                    .putExtra(AlarmClock.EXTRA_MESSAGE, (args["label"] as? String) ?: "ORBIT timer")
                    .putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                okMsg = "Asked the clock app to set a ${secs}s timer (it shows the timer for you to confirm)."
            }
            "alarm" -> {
                val h = (args["hour"] as? Number)?.toInt(); val m = (args["minute"] as? Number)?.toInt()
                if (h == null || m == null || h !in 0..23 || m !in 0..59) return status(false, "bad_args", "An alarm needs a valid hour and minute.")
                intent = Intent(AlarmClock.ACTION_SET_ALARM)
                    .putExtra(AlarmClock.EXTRA_HOUR, h).putExtra(AlarmClock.EXTRA_MINUTES, m)
                    .putExtra(AlarmClock.EXTRA_MESSAGE, (args["label"] as? String) ?: "ORBIT alarm")
                    .putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                okMsg = "Asked the clock app to set an alarm for %02d:%02d.".format(h, m)
            }
            "dial" -> {
                val n = (args["number"] as? String)?.filter { it.isDigit() || it == '+' || it == '*' || it == '#' }.orEmpty()
                if (n.isEmpty()) return status(false, "bad_args", "No phone number given.")
                // ACTION_DIAL only opens the dialer; ORBIT never places a call.
                intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:$n")); okMsg = "Opened the dialer with $n (nothing is called until you press call)."
            }
            "web" -> {
                val url = (args["url"] as? String)?.trim().orEmpty()
                val uri = Uri.parse(url)
                if (uri.scheme != "https" && uri.scheme != "http") return status(false, "bad_args", "Only http(s) links can be opened.")
                intent = Intent(Intent.ACTION_VIEW, uri); okMsg = "Asked Android to open $url."
            }
            "web_search" -> {
                val q = (args["query"] as? String)?.trim().orEmpty()
                if (q.isEmpty()) return status(false, "bad_args", "Nothing to search for.")
                intent = Intent(Intent.ACTION_WEB_SEARCH).putExtra("query", q); okMsg = "Asked a browser to search for '$q'."
            }
            else -> return status(false, "unsupported", "Unknown action '$kind'.")
        }
        return start(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK), okMsg)
    }

    private fun start(intent: Intent, okMsg: String): Map<String, Any?> {
        if (intent.resolveActivity(pm) == null && resolve(intent).isEmpty()) {
            return status(false, "no_handler", "No installed app can handle this action on this device.")
        }
        return try {
            context.startActivity(intent)
            status(true, "launched", okMsg)
        } catch (t: SecurityException) {
            status(false, "permission_denied", "Android blocked this action: ${t.message}")
        } catch (t: Throwable) {
            status(false, "launch_failed", t.message ?: "Could not start the activity.")
        }
    }

    private fun status(ok: Boolean, code: String, message: String) =
        mapOf("ok" to ok, "code" to code, "message" to message)

    private fun deviceInfo(): Map<String, Any?> {
        val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        return mapOf(
            "totalRam" to mi.totalMem, "availRam" to mi.availMem, "lowRam" to am.isLowRamDevice,
            "sdk" to Build.VERSION.SDK_INT, "manufacturer" to Build.MANUFACTURER, "model" to Build.MODEL,
            "abis" to Build.SUPPORTED_ABIS.toList(),
        )
    }

    companion object { const val CHANNEL = "orbit/apps" }
}
