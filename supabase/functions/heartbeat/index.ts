// Supabase Edge Function: heartbeat
// Receives device alive pings, updates last_seen_at, and detects guard-silent gaps

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface HeartbeatPayload {
  deviceId: string;
  appVersion: string;
  guardEnabled: boolean;
  platform?: string;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    // Verify token using anon client with user header
    const userClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await userClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Invalid user token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const payload: HeartbeatPayload = await req.json();
    if (!payload.deviceId) {
      return new Response(JSON.stringify({ error: "Missing deviceId" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const now = new Date();

    // 1. Fetch existing device record to check previous last_seen_at
    const { data: existingDevice } = await supabaseClient
      .from("devices")
      .select("last_seen_at, guard_enabled")
      .eq("id", payload.deviceId)
      .eq("user_id", user.id)
      .maybeSingle();

    let gapDetected = false;
    let gapSeconds = 0;

    if (existingDevice && existingDevice.last_seen_at) {
      const prevTime = new Date(existingDevice.last_seen_at).getTime();
      const currTime = now.getTime();
      gapSeconds = Math.round((currTime - prevTime) / 1000);

      // Gaps exceeding 3 hours (10800s) during supposedly active guard trigger a silent gap event
      if (gapSeconds > 10800 && existingDevice.guard_enabled) {
        gapDetected = true;
        await supabaseClient.from("guard_events").insert({
          user_id: user.id,
          ts: now.toISOString(),
          type: "guard_off",
          meta: {
            reason: "guard_silent_gap",
            gapSeconds,
            deviceId: payload.deviceId,
          },
        });
      }
    }

    // 2. Upsert device status
    await supabaseClient.from("devices").upsert({
      id: payload.deviceId,
      user_id: user.id,
      platform: payload.platform ?? "android",
      app_version: payload.appVersion ?? "1.0.0",
      last_seen_at: now.toISOString(),
      guard_enabled: payload.guardEnabled,
    });

    return new Response(
      JSON.stringify({
        success: true,
        serverTime: now.toISOString(),
        gapDetected,
        gapSeconds,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
