// Supabase Edge Function: sync-day
// Idempotently syncs daily stats, penalty events, and guard events

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface SyncPayload {
  dailyStats?: Array<{
    date: string;
    feed_seconds: number;
    swipe_count: number;
    lock_count: number;
    strike_count: number;
  }>;
  penaltyEvents?: Array<{
    id: string;
    ts: string;
    app_id: string;
    level: number;
    reason: string;
    budget_fraction: number;
    meta?: Record<string, unknown>;
  }>;
  guardEvents?: Array<{
    id: string;
    ts: string;
    type: string;
    meta?: Record<string, unknown>;
  }>;
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

    const payload: SyncPayload = await req.json();
    const syncedIds: string[] = [];

    // 1. Upsert Daily Stats
    if (payload.dailyStats && payload.dailyStats.length > 0) {
      for (const stat of payload.dailyStats) {
        const { error } = await supabaseClient
          .from("daily_stats")
          .upsert({
            user_id: user.id,
            date: stat.date,
            feed_seconds: stat.feed_seconds,
            swipe_count: stat.swipe_count,
            lock_count: stat.lock_count,
            strike_count: stat.strike_count,
          }, { onConflict: "user_id,date" });

        if (error) {
          console.error("Failed to upsert daily stats:", error);
        } else {
          syncedIds.push(`stat_${stat.date}`);
        }
      }
    }

    // 2. Insert Penalty Events (idempotent by id)
    if (payload.penaltyEvents && payload.penaltyEvents.length > 0) {
      for (const p of payload.penaltyEvents) {
        const { error } = await supabaseClient
          .from("penalty_events")
          .upsert({
            id: p.id,
            user_id: user.id,
            ts: p.ts,
            app_id: p.app_id,
            level: p.level,
            reason: p.reason,
            budget_fraction: p.budget_fraction,
            meta: p.meta ?? {},
          }, { onConflict: "id", ignoreDuplicates: true });

        if (error) {
          console.error("Failed to upsert penalty event:", error);
        } else {
          syncedIds.push(p.id);
        }
      }
    }

    // 3. Insert Guard Events (idempotent by id)
    if (payload.guardEvents && payload.guardEvents.length > 0) {
      for (const g of payload.guardEvents) {
        const { error } = await supabaseClient
          .from("guard_events")
          .upsert({
            id: g.id,
            user_id: user.id,
            ts: g.ts,
            type: g.type,
            meta: g.meta ?? {},
          }, { onConflict: "id", ignoreDuplicates: true });

        if (error) {
          console.error("Failed to upsert guard event:", error);
        } else {
          syncedIds.push(g.id);
        }
      }
    }

    return new Response(
      JSON.stringify({ success: true, syncedCount: syncedIds.length, syncedIds }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
