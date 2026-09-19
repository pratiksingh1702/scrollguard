// Supabase Edge Function: get-rules
// Returns the latest active detector_rules matching client app build and staged rollout percentage

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function djb2Hash(str: string): number {
  let hash = 5381;
  for (let i = 0; i < str.length; i++) {
    hash = ((hash << 5) + hash) + str.charCodeAt(i);
    hash = hash & hash; // Convert to 32bit integer
  }
  return Math.abs(hash);
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    let appBuild = 1;
    let deviceId = "";

    if (req.method === "GET") {
      const url = new URL(req.url);
      const buildParam = url.searchParams.get("app_build");
      if (buildParam) {
        appBuild = parseInt(buildParam, 10) || 1;
      }
      deviceId = url.searchParams.get("device_id") || "";
    } else if (req.method === "POST") {
      try {
        const body = await req.json();
        if (body.app_build) {
          appBuild = parseInt(body.app_build, 10) || 1;
        }
        if (body.device_id) {
          deviceId = String(body.device_id);
        }
      } catch {
        // Fallback to default params if body is empty or not JSON
      }
    }

    const supabaseClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    // Fetch active rules compatible with client build, ordered by version descending
    const { data: candidates, error } = await supabaseClient
      .from("detector_rules")
      .select("version, rules, min_app_build, rollout_percentage")
      .eq("is_active", true)
      .lte("min_app_build", appBuild)
      .order("version", { ascending: false });

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!candidates || candidates.length === 0) {
      return new Response(
        JSON.stringify({
          version: 0,
          rules: null,
          message: "No active rules found for app build",
        }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Evaluate staged rollout
    let selectedRule = null;
    for (const rule of candidates) {
      const rollout = rule.rollout_percentage ?? 100;
      if (rollout >= 100) {
        selectedRule = rule;
        break;
      }

      if (deviceId.length > 0) {
        const hashVal = djb2Hash(`${deviceId}:${rule.version}`);
        const bucket = hashVal % 100;
        if (bucket < rollout) {
          selectedRule = rule;
          break;
        }
      }
    }

    // Fallback to the latest rule with 100% rollout if not in staged bucket
    if (!selectedRule) {
      selectedRule = candidates.find((r: { rollout_percentage?: number }) => (r.rollout_percentage ?? 100) >= 100) || candidates[candidates.length - 1];
    }

    return new Response(
      JSON.stringify({
        version: selectedRule.version,
        rules: selectedRule.rules,
        rollout_percentage: selectedRule.rollout_percentage ?? 100,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
