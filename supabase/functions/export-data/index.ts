// Supabase Edge Function: export-data
// GDPR compliance data export: bundles all user records into structured JSON

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

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
      Deno.env.get("SUPABASE_ANON_KEY") ?? "",
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: userError } = await supabaseClient.auth.getUser();
    if (userError || !user) {
      return new Response(JSON.stringify({ error: "Invalid user token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Query all user-owned data
    const [
      profileRes,
      devicesRes,
      rulesRes,
      statsRes,
      penaltiesRes,
      guardEventsRes,
      contractsRes,
    ] = await Promise.all([
      supabaseClient.from("profiles").select("*").eq("id", user.id).maybeSingle(),
      supabaseClient.from("devices").select("*").eq("user_id", user.id),
      supabaseClient.from("rules_config").select("*").eq("user_id", user.id).maybeSingle(),
      supabaseClient.from("daily_stats").select("*").eq("user_id", user.id),
      supabaseClient.from("penalty_events").select("*").eq("user_id", user.id),
      supabaseClient.from("guard_events").select("*").eq("user_id", user.id),
      supabaseClient.from("contracts").select("*, charges(*)").eq("user_id", user.id),
    ]);

    const exportBundle = {
      exportedAt: new Date().toISOString(),
      user: {
        id: user.id,
        email: user.email,
        createdAt: user.created_at,
      },
      profile: profileRes.data,
      devices: devicesRes.data ?? [],
      rulesConfig: rulesRes.data,
      dailyStats: statsRes.data ?? [],
      penaltyEvents: penaltiesRes.data ?? [],
      guardEvents: guardEventsRes.data ?? [],
      contracts: contractsRes.data ?? [],
      privacyNotice: "ScrollGuard stores zero screen text, video titles, or messaging content.",
    };

    return new Response(JSON.stringify(exportBundle, null, 2), {
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
        "Content-Disposition": `attachment; filename="scrollguard_export_${user.id}.json"`,
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
