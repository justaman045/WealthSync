package app.vercel.justaman045.money_control

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.concurrent.thread

class MainActivity : FlutterFragmentActivity() {
    private val UPI_CHANNEL = "money_control/upi"
    private val UPI_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPI_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getInstallerPackageName") {
                    thread {
                        val installer = try {
                            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
                                packageManager.getInstallSourceInfo(packageName).installingPackageName
                            } else {
                                @Suppress("DEPRECATION")
                                packageManager.getInstallerPackageName(packageName)
                            }
                        } catch (e: Exception) { null }
                        runOnUiThread { result.success(installer) }
                    }
                } else if (call.method == "pay") {
                    if (pendingResult != null) {
                        result.error("BUSY", "A UPI payment is already in progress", null)
                        return@setMethodCallHandler
                    }

                    val packageName = call.argument<String>("packageName")
                    val amount     = call.argument<String>("amount") ?: ""
                    val payeeName  = call.argument<String>("payeeName") ?: ""
                    val payeeVpa   = call.argument<String>("payeeVpa") ?: ""
                    val note       = call.argument<String>("note") ?: ""

                    if (payeeVpa.isEmpty()) {
                        result.error("MISSING_VPA", "payeeVpa (pa) is required for UPI payments", null)
                        return@setMethodCallHandler
                    }

                    val uri = Uri.parse(
                        "upi://pay?pa=${Uri.encode(payeeVpa)}&pn=${Uri.encode(payeeName)}&am=$amount&cu=INR&tn=${Uri.encode(note)}"
                    )
                    val intent = Intent(Intent.ACTION_VIEW, uri)
                    if (!packageName.isNullOrEmpty()) intent.setPackage(packageName)

                    pendingResult = result
                    try {
                        startActivityForResult(intent, UPI_REQUEST_CODE)
                    } catch (e: ActivityNotFoundException) {
                        pendingResult = null
                        result.error("APP_NOT_FOUND", "No UPI app found", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == UPI_REQUEST_CODE) {
            // UPI apps return the result as a query-string in the "response" extra.
            // Empty string means the user cancelled (pressed back).
            val response = data?.getStringExtra("response") ?: ""
            pendingResult?.success(response)
            pendingResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Prevent dangling result reference if activity is destroyed mid-payment
        pendingResult?.error("CANCELLED", "Payment cancelled (activity destroyed)", null)
        pendingResult = null
    }
}
