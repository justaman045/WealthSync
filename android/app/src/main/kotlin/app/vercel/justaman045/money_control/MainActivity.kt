package app.vercel.justaman045.money_control

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val UPI_CHANNEL = "money_control/upi"
    private val UPI_REQUEST_CODE = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UPI_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "pay") {
                    val packageName = call.argument<String>("packageName")
                    val amount     = call.argument<String>("amount") ?: ""
                    val payeeName  = call.argument<String>("payeeName") ?: ""
                    val note       = call.argument<String>("note") ?: ""

                    val uri = Uri.parse(
                        "upi://pay?pn=${Uri.encode(payeeName)}&am=$amount&cu=INR&tn=${Uri.encode(note)}"
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
}
