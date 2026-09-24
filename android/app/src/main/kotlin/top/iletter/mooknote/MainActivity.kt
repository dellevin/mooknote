package top.iletter.mooknote

import android.content.ComponentName
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.os.Environment
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "top.iletter.mooknote/icon"
    private val MEDIA_SCAN_CHANNEL = "top.iletter.mooknote/media_scan"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "switchIcon" -> {
                    val iconName = call.argument<String>("iconName")
                    if (iconName != null) {
                        switchLauncherIcon(iconName)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGUMENT", "iconName is required", null)
                    }
                }
                "getCurrentIcon" -> {
                    result.success(getCurrentIcon())
                }
                else -> result.notImplemented()
            }
        }

        // 系统媒体库扫描：重新索引公共图片目录（Pictures / DCIM），
        // 解决图片已在存储中但系统相册/图片选择器看不到的问题
        val mediaScanChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_SCAN_CHANNEL)
        mediaScanChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "scanMedia" -> {
                    Thread {
                        val paths = collectImagePaths()
                        Handler(Looper.getMainLooper()).post {
                            if (paths.isEmpty()) {
                                result.success(0)
                            } else {
                                val total = paths.size
                                var done = 0
                                val mainHandler = Handler(Looper.getMainLooper())
                                MediaScannerConnection.scanFile(this, paths.toTypedArray(), null) { _, _ ->
                                    // 该回调跑在 MediaScanner 的后台线程，Flutter 通道调用必须切回主线程
                                    mainHandler.post {
                                        done++
                                        mediaScanChannel.invokeMethod("onProgress", mapOf("done" to done, "total" to total))
                                        if (done >= total) {
                                            result.success(total)
                                        }
                                    }
                                }
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    // 遍历公共图片目录，收集图片文件路径（不扫描应用私有目录，避免污染系统相册）
    private fun collectImagePaths(): List<String> {
        val exts = setOf("jpg", "jpeg", "png", "webp", "gif", "bmp", "heic", "heif", "avif")
        val roots = listOf(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM)
        )
        val paths = ArrayList<String>()
        for (root in roots) {
            try {
                root?.walkTopDown()?.forEach { f ->
                    if (f.isFile && exts.contains(f.extension.lowercase())) {
                        paths.add(f.absolutePath)
                    }
                }
            } catch (_: Exception) {
                // 目录不可读（未授权等）时跳过
            }
        }
        return paths
    }

    private fun switchLauncherIcon(iconName: String) {
        val pm = packageManager
        val mainActivity = ComponentName(this, "${packageName}.MainActivity")
        val icon1 = ComponentName(this, "${packageName}.MainActivityIcon1")
        val icon2 = ComponentName(this, "${packageName}.MainActivityIcon2")
        val icon3 = ComponentName(this, "${packageName}.MainActivityIcon3")

        // 先禁用所有别名
        pm.setComponentEnabledSetting(icon1, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        pm.setComponentEnabledSetting(icon2, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
        pm.setComponentEnabledSetting(icon3, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)

        when (iconName) {
            "app_icon2" -> {
                // 切换到图标2：禁用主Activity的LAUNCHER，启用别名
                pm.setComponentEnabledSetting(mainActivity, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(icon2, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            }
            "app_icon_m" -> {
                // 切换到图标3：禁用主Activity的LAUNCHER，启用别名
                pm.setComponentEnabledSetting(mainActivity, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(icon3, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            }
            else -> {
                // 切换回默认图标：启用主Activity，禁用所有别名（已在上面禁用）
                pm.setComponentEnabledSetting(mainActivity, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            }
        }
    }

    private fun getCurrentIcon(): String {
        val pm = packageManager
        val icon2 = ComponentName(this, "${packageName}.MainActivityIcon2")
        val icon3 = ComponentName(this, "${packageName}.MainActivityIcon3")

        return when {
            pm.getComponentEnabledSetting(icon2) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> "app_icon2"
            pm.getComponentEnabledSetting(icon3) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> "app_icon_m"
            else -> "app_icon"
        }
    }
}
