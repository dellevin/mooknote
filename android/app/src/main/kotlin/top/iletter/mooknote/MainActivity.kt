package top.iletter.mooknote

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "top.iletter.mooknote/icon"

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
    }

    private fun switchLauncherIcon(iconName: String) {
        val pm = packageManager
        val icon1 = ComponentName(this, "${packageName}.MainActivityIcon1")
        val icon2 = ComponentName(this, "${packageName}.MainActivityIcon2")

        when (iconName) {
            "app_icon2" -> {
                pm.setComponentEnabledSetting(icon1, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(icon2, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            }
            else -> {
                pm.setComponentEnabledSetting(icon2, PackageManager.COMPONENT_ENABLED_STATE_DISABLED, PackageManager.DONT_KILL_APP)
                pm.setComponentEnabledSetting(icon1, PackageManager.COMPONENT_ENABLED_STATE_ENABLED, PackageManager.DONT_KILL_APP)
            }
        }
    }

    private fun getCurrentIcon(): String {
        val pm = packageManager
        val icon1 = ComponentName(this, "${packageName}.MainActivityIcon1")
        val icon2 = ComponentName(this, "${packageName}.MainActivityIcon2")

        return when {
            pm.getComponentEnabledSetting(icon2) == PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> "app_icon2"
            else -> "app_icon"
        }
    }
}
