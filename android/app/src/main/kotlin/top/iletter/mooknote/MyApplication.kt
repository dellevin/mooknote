package top.iletter.mooknote

import android.app.Application
import com.umeng.commonsdk.UMConfigure

class MyApplication : Application() {
    override fun onCreate() {
        super.onCreate()

        // 预初始化
        UMConfigure.preInit(this, "6aed8d46863270068cb8ec23", "official")
    }
}
