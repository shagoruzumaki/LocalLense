import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")
const FIREBASE_CLIENT_EMAIL = Deno.env.get("FIREBASE_CLIENT_EMAIL")
const FIREBASE_PRIVATE_KEY = Deno.env.get("FIREBASE_PRIVATE_KEY")?.replace(/\\n/g, '\n')

serve(async (req) => {
  const { user_id, type, ...extra } = await req.json()

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  )

  // 1. Get user's FCM token
  const { data: profile } = await supabase
    .from("profiles")
    .select("fcm_token")
    .eq("id", user_id)
    .single()

  if (!profile?.fcm_token) {
    return new Response(JSON.stringify({ error: "No token found" }), { status: 400 })
  }

  // 2. Save notification to DB
  await supabase.from("notifications").insert({
    user_id,
    type,
    content: extra,
    is_read: false
  })

  // 3. Prepare FCM Payload
  const message = {
    message: {
      token: profile.fcm_token,
      notification: {
        title: getNotificationTitle(type),
        body: getNotificationBody(type, extra),
      },
      data: {
        type,
        ...extra,
      },
      android: {
        priority: "high",
        notification: {
          channel_id: getChannelId(type),
        },
      },
    },
  }

  // 4. Send via Firebase HTTP v1 API (simplified for this example)
  // In production, you'd use a library or fetch with OAuth2 token
  console.log("Sending FCM:", JSON.stringify(message))

  return new Response(JSON.stringify({ success: true }), { status: 200 })
})

function getNotificationTitle(type: string) {
  switch (type) {
    case "tier_upgrade": return "Tier Upgraded! 💎"
    case "reward_unlocked": return "New Reward Available! 🎁"
    case "verification": return "Account Verified! ✅"
    case "top10_updated": return "Weekly Top 10 is Out! 🏆"
    case "nearby_top10": return "Top 10 Spot Nearby! 📍"
    case "review_voted": return "Your Review was Helpful! 👍"
    default: return "LocalLens Update"
  }
}

function getNotificationBody(type: string, extra: any) {
  switch (type) {
    case "tier_upgrade": return `Congrats! You're now a ${extra.new_tier} member.`
    case "reward_unlocked": return "Check your profile to claim your reward."
    case "verification": return "You now have a verified badge on your profile."
    default: return "Check the app for details."
  }
}

function getChannelId(type: string) {
  if (type === "tier_upgrade" || type === "reward_unlocked") return "rewards_alerts"
  if (type === "nearby_top10") return "location_alerts"
  return "general_notifications"
}
