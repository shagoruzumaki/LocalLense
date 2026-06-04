package com.example.local_lense.notifications

enum class NotificationType(val type: String) {
    TIER_UPGRADE("tier_upgrade"),
    REWARD_UNLOCKED("reward_unlocked"),
    VERIFICATION("verification"),
    TOP10_UPDATED("top10_updated"),
    NEARBY_TOP10("nearby_top10"),
    REVIEW_VOTED("review_voted")
}

object NotificationConfig {
    const val CHANNEL_GENERAL_ID = "general_notifications"
    const val CHANNEL_REWARDS_ID = "rewards_alerts"
    const val CHANNEL_COMMUNITY_ID = "community_updates"
    const val CHANNEL_LOCATION_ID = "location_alerts"
    
    const val SUMMARY_ID = 1000
}
