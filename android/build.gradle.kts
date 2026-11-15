allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// flutter_inappwebview_android 1.1.3 的 release 自带 minifyEnabled true，
// AGP 8.11 R8 full mode 下其自引用缺失类会从警告升级为硬错误。
// 库模块无需单独 minify，最终裁剪由 :app 的 R8 统一完成。
// 用 withPlugin 而非 afterEvaluate：上方 evaluationDependsOn 会使子项目提前完成评估
subprojects {
    if (name == "flutter_inappwebview_android") {
        pluginManager.withPlugin("com.android.library") {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                buildTypes.named("release") {
                    isMinifyEnabled = false
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
