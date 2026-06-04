package com.example.local_lense.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build

class NotificationChannelManager(private val context: Context) {

    fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channels = listOf(
                NotificationChannel(
                    NotificationConfig.CHANNEL_GENERAL_ID,
                    "General Notifications",
                    NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "Used for account and system updates"
                },
                NotificationChannel(
                    NotificationConfig.CHANNEL_REWARDS_ID,
                    "Rewards & Tiers",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alerts for rewards unlocked and tier upgrades"
                },
                NotificationChannel(
                    NotificationConfig.CHANNEL_COMMUNITY_ID,
                    "Community Updates",
                    NotificationManager.IMPORTANCE_LOW
                ).apply {
                    description = "Updates on top 10 rankings and community activity"
                },
                NotificationChannel(
                    NotificationConfig.CHANNEL_LOCATION_ID,
                    "Location Alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Notifications based on your current location"
                }
            )

            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannels(channels)
        }
    }
}
