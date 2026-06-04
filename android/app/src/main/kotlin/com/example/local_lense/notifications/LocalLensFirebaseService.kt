package com.example.local_lense.notifications

import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.github.jan.supabase.SupabaseClient
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class LocalLensFirebaseService : FirebaseMessagingService() {

    private val scope = CoroutineScope(Dispatchers.IO)

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("FCM", "Refreshed token: $token")
        // Normally you'd get the Supabase client from an entry point or DI
        // For this example, we assume there's a way to save it to the profiles table
        saveTokenToSupabase(token)
    }

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)
        
        val type = remoteMessage.data["type"]
        val title = remoteMessage.notification?.title ?: "LocalLens Update"
        val body = remoteMessage.notification?.body ?: ""

        Log.d("FCM", "Message Received: $type")
        
        // Routing logic based on type
        when (type) {
            NotificationType.TIER_UPGRADE.type -> {
                // Handle tier upgrade (maybe show custom UI or high priority notification)
            }
            NotificationType.REWARD_UNLOCKED.type -> {
                // Show rewards notification
            }
            // Add other cases...
        }
    }

    private fun saveTokenToSupabase(token: String) {
        scope.launch {
            try {
                // This is a placeholder for actual Supabase integration logic
                // supabase.postgrest["profiles"].update(mapOf("fcm_token" to token)) {
                //    filter { eq("id", supabase.auth.currentUserOrNull()?.id ?: "") }
                // }
            } catch (e: Exception) {
                Log.e("FCM", "Error saving token", e)
            }
        }
    }
}
