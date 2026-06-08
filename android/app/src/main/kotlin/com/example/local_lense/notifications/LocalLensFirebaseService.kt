package com.example.local_lense.notifications

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class LocalLensFirebaseService : FirebaseMessagingService() {

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("FCM", "Refreshed token: $token")
        // Token update is handled in Flutter via notification_service.dart
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        val type = remoteMessage.data["type"]
        val title = remoteMessage.notification?.title ?: "LocalLens Update"
        val body = remoteMessage.notification?.body ?: ""

        Log.d("FCM", "Message Received: $type")
        
        // Custom routing or high-priority alerts can be handled here if needed.
        // Most logic is handled in the Flutter layer.
    }
}
