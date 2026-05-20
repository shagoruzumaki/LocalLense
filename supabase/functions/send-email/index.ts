// LocalLens · Email Service Edge Function
// Deploy to: supabase/functions/send-email/index.ts
// Uses Resend (https://resend.com) as email provider
// Member 1 — Ismail Hossain Shagor

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
const FROM_EMAIL = "LocalLens <noreply@yourdomain.com>"; // replace with your domain

// ─────────────────────────────────────────────
// EMAIL TEMPLATES
// ─────────────────────────────────────────────

function verificationApprovedTemplate(userName: string): string {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background-color: #FF5722; padding: 24px; text-align: center;">
        <h1 style="color: white; margin: 0;">LocalLens</h1>
      </div>
      <div style="padding: 32px; background-color: #ffffff;">
        <h2 style="color: #333333;">Account Verified! ✅</h2>
        <p style="color: #555555; font-size: 16px;">Hi ${userName},</p>
        <p style="color: #555555; font-size: 16px;">
          Your account has been successfully verified. A verified badge has been added to your profile.
        </p>
        <p style="color: #555555; font-size: 16px;">
          You can now enjoy the full LocalLens experience with your verified status!
        </p>
        <div style="text-align: center; margin: 32px 0;">
          <a href="locallens://profile"
             style="background-color: #FF5722; color: white; padding: 12px 32px;
                    text-decoration: none; border-radius: 8px; font-size: 16px;">
            View My Profile
          </a>
        </div>
      </div>
      <div style="padding: 16px; text-align: center; color: #999999; font-size: 12px;">
        © 2025 LocalLens · All rights reserved
      </div>
    </div>
  `;
}

function verificationRejectedTemplate(userName: string, reason: string): string {
  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background-color: #FF5722; padding: 24px; text-align: center;">
        <h1 style="color: white; margin: 0;">LocalLens</h1>
      </div>
      <div style="padding: 32px; background-color: #ffffff;">
        <h2 style="color: #333333;">Verification Update</h2>
        <p style="color: #555555; font-size: 16px;">Hi ${userName},</p>
        <p style="color: #555555; font-size: 16px;">
          Unfortunately, your verification request was not approved for the following reason:
        </p>
        <div style="background-color: #FFF3E0; border-left: 4px solid #FF5722;
                    padding: 16px; margin: 16px 0; border-radius: 4px;">
          <p style="color: #333333; margin: 0; font-size: 15px;">${reason}</p>
        </div>
        <p style="color: #555555; font-size: 16px;">
          You can resubmit your verification with the correct documents.
        </p>
        <div style="text-align: center; margin: 32px 0;">
          <a href="locallens://verification"
             style="background-color: #FF5722; color: white; padding: 12px 32px;
                    text-decoration: none; border-radius: 8px; font-size: 16px;">
            Resubmit Verification
          </a>
        </div>
      </div>
      <div style="padding: 16px; text-align: center; color: #999999; font-size: 12px;">
        © 2025 LocalLens · All rights reserved
      </div>
    </div>
  `;
}

function tierUpgradeTemplate(userName: string, newTier: string): string {
  const tierColors: Record<string, string> = {
    expert: "#4CAF50",
    diamond: "#2196F3",
    platinum: "#9C27B0",
  };
  const color = tierColors[newTier] ?? "#FF5722";

  return `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <div style="background-color: #FF5722; padding: 24px; text-align: center;">
        <h1 style="color: white; margin: 0;">LocalLens</h1>
      </div>
      <div style="padding: 32px; background-color: #ffffff; text-align: center;">
        <h2 style="color: #333333;">You've levelled up! 🎉</h2>
        <p style="color: #555555; font-size: 16px;">Hi ${userName},</p>
        <p style="color: #555555; font-size: 16px;">
          The community loves your reviews! You've been promoted to:
        </p>
        <div style="background-color: ${color}; color: white; display: inline-block;
                    padding: 12px 32px; border-radius: 24px; font-size: 22px;
                    font-weight: bold; margin: 16px 0; text-transform: capitalize;">
          ${newTier}
        </div>
        <p style="color: #555555; font-size: 16px;">
          New rewards have been unlocked on your account. Check them out!
        </p>
        <div style="text-align: center; margin: 32px 0;">
          <a href="locallens://rewards"
             style="background-color: #FF5722; color: white; padding: 12px 32px;
                    text-decoration: none; border-radius: 8px; font-size: 16px;">
            View My Rewards
          </a>
        </div>
      </div>
      <div style="padding: 16px; text-align: center; color: #999999; font-size: 12px;">
        © 2025 LocalLens · All rights reserved
      </div>
    </div>
  `;
}

// ─────────────────────────────────────────────
// MAIN HANDLER
// ─────────────────────────────────────────────
serve(async (req) => {
  // Only allow POST
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const { type, to, userName, data } = await req.json();

    let subject = "";
    let html = "";

    // Route to correct template based on type
    switch (type) {
      case "verification_approved":
        subject = "Your LocalLens account is now verified ✅";
        html = verificationApprovedTemplate(userName);
        break;

      case "verification_rejected":
        subject = "Update on your LocalLens verification";
        html = verificationRejectedTemplate(userName, data.reason);
        break;

      case "tier_upgrade":
        subject = `You've reached ${data.newTier} on LocalLens! 🎉`;
        html = tierUpgradeTemplate(userName, data.newTier);
        break;

      default:
        return new Response(
          JSON.stringify({ error: "Unknown email type" }),
          { status: 400, headers: { "Content-Type": "application/json" } }
        );
    }

    // Send via Resend API
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: FROM_EMAIL,
        to: [to],
        subject,
        html,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error("Resend error:", error);
      return new Response(
        JSON.stringify({ error: "Failed to send email" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    return new Response(
      JSON.stringify({ success: true }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("Edge function error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});