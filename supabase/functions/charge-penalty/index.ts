// Supabase Edge Function: charge-penalty
// Idempotent charge engine enforcing caps, contract state, and false-positive checks

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

    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    const body = await req.json();
    const { penalty_event_id, user_id } = body;

    if (!penalty_event_id || !user_id) {
      return new Response(JSON.stringify({ error: "Missing penalty_event_id or user_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 1. IDEMPOTENCY CHECK: Check if penalty_event_id was already charged
    const { data: existingCharge } = await adminClient
      .from("charges")
      .select("*")
      .eq("penalty_event_id", penalty_event_id)
      .maybeSingle();

    if (existingCharge) {
      return new Response(
        JSON.stringify({
          success: true,
          status: existingCharge.status,
          message: "Idempotent: Charge already exists for this penalty event.",
          charge: existingCharge,
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 2. CONTRACT STATUS CHECK
    const { data: contract, error: contractErr } = await adminClient
      .from("contracts")
      .select("*")
      .eq("user_id", user_id)
      .eq("status", "active")
      .maybeSingle();

    if (contractErr || !contract) {
      return new Response(
        JSON.stringify({
          success: false,
          skipped: true,
          reason: "No active commitment contract for user.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Cooling off check: If cooling_off_until is in future, don't charge
    if (contract.cooling_off_until && new Date(contract.cooling_off_until) > new Date()) {
      return new Response(
        JSON.stringify({
          success: false,
          skipped: true,
          reason: "Contract is in cooling-off period.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. FALSE-POSITIVE PROTECTION (P7-T5)
    // Fetch penalty event details
    const { data: penaltyEvent } = await adminClient
      .from("penalty_events")
      .select("*")
      .eq("id", penalty_event_id)
      .maybeSingle();

    if (penaltyEvent?.meta?.rules_stale === true) {
      return new Response(
        JSON.stringify({
          success: false,
          skipped: true,
          reason: "False-positive protection: Penalty event marked with rules_stale.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Check recent guard events in past hour for divergence or stale rules
    const oneHourAgo = new Date(Date.now() - 3600 * 1000).toISOString();
    const { data: recentGuardEvents } = await adminClient
      .from("guard_events")
      .select("*")
      .eq("user_id", user_id)
      .gte("created_at", oneHourAgo);

    const hasStaleOrDivergence = recentGuardEvents?.some(
      (ev) => ev.event_type === "rules_stale" || ev.event_type === "usage_divergence"
    );

    if (hasStaleOrDivergence) {
      return new Response(
        JSON.stringify({
          success: false,
          skipped: true,
          reason: "False-positive protection: Detector drift or usage divergence detected in window.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. CAPS ENFORCEMENT
    const now = new Date();
    const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).toISOString();
    const sevenDaysAgo = new Date(Date.now() - 7 * 86400 * 1000).toISOString();

    const { data: pastCharges } = await adminClient
      .from("charges")
      .select("amount_cents, created_at, status")
      .eq("contract_id", contract.id)
      .in("status", ["succeeded", "pending"]);

    let todayCents = 0;
    let weeklyCents = 0;

    for (const c of pastCharges ?? []) {
      if (c.created_at >= startOfToday) {
        todayCents += c.amount_cents;
      }
      if (c.created_at >= sevenDaysAgo) {
        weeklyCents += c.amount_cents;
      }
    }

    let chargeAmount = contract.per_penalty_cents;

    // Check daily cap
    if (todayCents >= contract.daily_cap_cents) {
      return new Response(
        JSON.stringify({
          success: false,
          skipped: true,
          reason: "Daily penalty cap reached.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (todayCents + chargeAmount > contract.daily_cap_cents) {
      chargeAmount = contract.daily_cap_cents - todayCents;
    }

    // Check weekly cap
    if (weeklyCents >= contract.weekly_cap_cents) {
      return new Response(
        JSON.stringify({
          success: false,
          skipped: true,
          reason: "Weekly penalty cap reached.",
        }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }
    if (weeklyCents + chargeAmount > contract.weekly_cap_cents) {
      chargeAmount = contract.weekly_cap_cents - weeklyCents;
    }

    if (chargeAmount <= 0) {
      return new Response(
        JSON.stringify({ success: false, skipped: true, reason: "Caps exceeded." }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 5. STRIPE EXECUTION (Off-session PaymentIntent)
    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "mock_stripe_key";
    let paymentIntentId = `pi_mock_${Date.now()}`;
    let status = "succeeded";
    let failureReason: string | null = null;

    if (stripeSecret !== "mock_stripe_key" && contract.stripe_pm_id && contract.stripe_customer_id) {
      const piParams = new URLSearchParams({
        amount: chargeAmount.toString(),
        currency: "usd",
        customer: contract.stripe_customer_id,
        payment_method: contract.stripe_pm_id,
        off_session: "true",
        confirm: "true",
        "metadata[penalty_event_id]": penalty_event_id,
        "metadata[contract_id]": contract.id,
      });

      const piRes = await fetch("https://api.stripe.com/v1/payment_intents", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecret}`,
          "Content-Type": "application/x-www-form-urlencoded",
          "Idempotency-Key": penalty_event_id,
        },
        body: piParams.toString(),
      });

      const piData = await piRes.json();
      if (!piRes.ok) {
        status = "failed";
        failureReason = piData.error?.message ?? "Payment failed";
      } else {
        paymentIntentId = piData.id;
        status = piData.status === "succeeded" ? "succeeded" : "pending";
      }
    }

    // 6. RECORD CHARGE
    const { data: newCharge, error: insertErr } = await adminClient
      .from("charges")
      .insert({
        contract_id: contract.id,
        penalty_event_id: penalty_event_id,
        amount_cents: chargeAmount,
        stripe_payment_intent_id: paymentIntentId,
        status: status,
        failure_reason: failureReason,
      })
      .select()
      .single();

    if (insertErr) throw insertErr;

    // If charge failed, check if we need to pause contract
    if (status === "failed") {
      const { count } = await adminClient
        .from("charges")
        .select("*", { count: "exact", head: true })
        .eq("contract_id", contract.id)
        .eq("status", "failed");

      if ((count ?? 0) >= 3) {
        await adminClient
          .from("contracts")
          .update({ status: "paused" })
          .eq("id", contract.id);
      }
    }

    return new Response(
      JSON.stringify({
        success: status === "succeeded",
        charge: newCharge,
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
