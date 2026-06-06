package com.example.local_lense

import android.os.Bundle
import com.example.local_lense.notifications.NotificationChannelManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Initialize Notification Channels
        NotificationChannelManager(this).createNotificationChannels()
    }
}
