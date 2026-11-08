import Flutter
import UIKit
import UMCommon
import UMAPM

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
        // 友盟APM采集开关配置
        let config = UMAPMConfig.defaultConfig()
        config?.crashAndBlockMonitorEnable = true
        config?.launchMonitorEnable = true
        config?.memMonitorEnable = false
        config?.oomMonitorEnable = false
        config?.networkEnable = true
        UMCrashConfigure.setAPMConfig(config)


    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
