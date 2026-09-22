allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// agora_rtc_engine's own android/build.gradle hardcodes compileSdkVersion
// 31 as its default (`safeExtGet('compileSdkVersion', 31)`), too low for
// several AndroidX libraries it pulls in transitively (androidx.tracing,
// androidx.exifinterface, etc., which need 33/34+). Setting this root
// `ext` property is exactly the override mechanism that fallback exists
// for — Agora's own build.gradle reads it before falling back to 31.
// Matches this app's own compileSdk (flutter.compileSdkVersion, already
// 36 on this Flutter version) so there's one consistent number, not two.
rootProject.extra["compileSdkVersion"] = 36

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
