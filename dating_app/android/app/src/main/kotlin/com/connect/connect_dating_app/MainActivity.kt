package com.connect.connect_dating_app

import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerClient.InstallReferrerResponse
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Acquisition-source tracking (spec section 17) — real Google Play
 * Install Referrer data, queried directly against Google's own
 * `com.android.installreferrer:installreferrer` library rather than
 * through a third-party Dart wrapper. That wrapper
 * (`android_play_install_referrer`, pinned at 0.4.0 with no newer
 * release on pub.dev) ships an AAR compiled against API 33, which
 * Gradle's AAR-metadata check rejects once other dependencies
 * (androidx.fragment 1.7.1+, pulled in transitively via
 * google_mobile_ads/Firebase) require compileSdk 34+. This
 * platform-channel implementation compiles against this app's own
 * compileSdk (see android/app/build.gradle.kts), so there's no
 * version-skew to hit — same real Google API, no broken wrapper.
 *
 * See `AcquisitionSourceService` (lib/data/repositories/firebase/) for
 * the Dart side that calls this channel and parses the result.
 */
class MainActivity : FlutterActivity() {
    private val channelName = "connect/install_referrer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            if (call.method == "getInstallReferrer") {
                fetchInstallReferrer(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun fetchInstallReferrer(result: MethodChannel.Result) {
        // MethodChannel.Result isn't safe to call twice — the
        // referrer-client callback and the connection-lost callback
        // could both fire in edge cases, so guard against delivering
        // twice rather than crash the platform channel.
        var delivered = false
        fun deliver(value: String?) {
            if (delivered) return
            delivered = true
            result.success(value)
        }

        val referrerClient = InstallReferrerClient.newBuilder(applicationContext).build()
        try {
            referrerClient.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    try {
                        if (responseCode == InstallReferrerResponse.OK) {
                            deliver(referrerClient.installReferrer.installReferrer)
                        } else {
                            // FEATURE_NOT_SUPPORTED (no Play Store on this
                            // device), SERVICE_UNAVAILABLE,
                            // SERVICE_DISCONNECTED, DEVELOPER_ERROR — all
                            // mean "no referrer to report", not a failure
                            // worth propagating to Dart as an error.
                            deliver(null)
                        }
                    } catch (e: Exception) {
                        deliver(null)
                    } finally {
                        try {
                            referrerClient.endConnection()
                        } catch (e: Exception) {
                            // Already disconnected — nothing to clean up.
                        }
                    }
                }

                override fun onInstallReferrerServiceDisconnected() {
                    deliver(null)
                }
            })
        } catch (e: Exception) {
            // Play Services entirely unavailable on this device.
            deliver(null)
        }
    }
}
