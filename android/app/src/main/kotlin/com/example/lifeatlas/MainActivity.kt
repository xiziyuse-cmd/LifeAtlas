package com.example.lifeatlas

import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val updatesExecutor = Executors.newSingleThreadExecutor()
    @Suppress("DEPRECATION")
    private fun flags() = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
    @Suppress("DEPRECATION")
    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
    @Suppress("DEPRECATION")
    private fun signatures(info: PackageInfo): Set<String> {
        val values = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
        return values?.map { sig -> MessageDigest.getInstance("SHA-256").digest(sig.toByteArray()).joinToString("") { "%02x".format(it) } }?.toSet() ?: emptySet()
    }
    private fun verifiedFile(call: io.flutter.plugin.common.MethodCall): File {
        val file = File(call.argument<String>("path") ?: error("安装包路径无效")).canonicalFile
        val allowed = File(cacheDir, "updates").canonicalFile
        require(file.parentFile == allowed && file.extension == "apk" && file.isFile) { "安装包路径无效，请重新下载" }
        require(file.length() == call.argument<Number>("size")?.toLong()) { "安装包大小不匹配，请重新下载" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input -> val bytes = ByteArray(65536); while (true) { val count = input.read(bytes); if (count < 0) break; digest.update(bytes, 0, count) } }
        val sha = digest.digest().joinToString("") { "%02x".format(it) }
        require(sha == call.argument<String>("sha256")) { "安装包校验失败，请重新下载" }
        val archive = packageManager.getPackageArchiveInfo(file.path, flags()) ?: error("安装包无法解析")
        val current = packageManager.getPackageInfo(packageName, flags())
        require(archive.packageName == packageName) { "安装包不属于 LifeAtlas" }
        require(version(archive) == call.argument<Number>("build")?.toLong() && version(archive) > version(current) && archive.versionName == call.argument<String>("version")) { "安装包版本不匹配或版本已过期，请重新检查更新" }
        require((archive.applicationInfo?.minSdkVersion ?: Int.MAX_VALUE) <= Build.VERSION.SDK_INT) { "当前 Android 系统不支持此版本" }
        val expected = signatures(current)
        require(expected.isNotEmpty() && signatures(archive) == expected) { "安装包签名与当前版本不一致，无法保留数据覆盖升级。请联系开发者提供同签名版本，无需卸载当前应用。" }
        return file
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "lifeatlas/updates").setMethodCallHandler { call, result ->
            if (call.method == "deviceInfo") {
                val info = packageManager.getPackageInfo(packageName, 0)
                result.success(mapOf("version" to info.versionName, "build" to version(info), "sdk" to Build.VERSION.SDK_INT))
            } else if (call.method == "verifyApk" || call.method == "install") {
                updatesExecutor.execute {
                    try {
                        val file = verifiedFile(call)
                        runOnUiThread {
                            try {
                                if (call.method == "verifyApk") result.success(null)
                                else if (Build.VERSION.SDK_INT >= 26 && !packageManager.canRequestPackageInstalls()) {
                                    startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES, Uri.parse("package:$packageName")))
                                    result.success("permissionRequired")
                                } else {
                                    val uri = FileProvider.getUriForFile(this, "$packageName.updates", file)
                                    startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/vnd.android.package-archive").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                                    result.success("opened")
                                }
                            } catch (_: Exception) { result.error("INSTALL_FAILED", "无法打开系统安装页面，请重试", null) }
                        }
                    } catch (error: Exception) { runOnUiThread { result.error("UPDATE_INVALID", error.message ?: "安装校验失败", null) } }
                }
            } else result.notImplemented()
        }
    }
    override fun onDestroy() { updatesExecutor.shutdown(); super.onDestroy() }
}
