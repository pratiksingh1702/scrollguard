// Supabase Edge Function: create-setup-intent
// Creates a Stripe Customer (if not exists) and a SetupIntent for off-session card saving

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

    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") ?? "mock_stripe_key";

    // 1. Check if user already has a contract with a stripe_customer_id
    const { data: contract } = await supabaseClient
      .from("contracts")
      .select("stripe_customer_id")
      .eq("user_id", user.id)
      .maybeSingle();

    let customerId = contract?.stripe_customer_id;

    // In production or test mode with real Stripe key:
    if (!customerId && stripeSecret !== "mock_stripe_key") {
      const customerParams = new URLSearchParams({
        email: user.email ?? "",
        "metadata[user_id]": user.id,
      });

      const custRes = await fetch("https://api.stripe.com/v1/customers", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecret}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: customerParams.toString(),
      });

      const custData = await custRes.json();
      if (!custRes.ok) {
        throw new Error(`Stripe customer error: ${custData.error?.message || "unknown"}`);
      }
      customerId = custData.id;
    } else if (!customerId) {
      customerId = `cus_mock_${user.id.substring(0, 8)}`;
    }

    // 2. Create SetupIntent
    let clientSecret = `seti_mock_${Date.now()}_secret_${Math.random().toString(36).substring(7)}`;

    if (stripeSecret !== "mock_stripe_key") {
      const setupParams = new URLSearchParams({
        customer: customerId,
        "payment_method_types[]": "card",
        usage: "off_session",
      });

      const setupRes = await fetch("https://api.stripe.com/v1/setup_intents", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${stripeSecret}`,
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: setupParams.toString(),
      });

      const setupData = await setupRes.json();
      if (!setupRes.ok) {
        throw new Error(`Stripe SetupIntent error: ${setupData.error?.message || "unknown"}`);
      }
      clientSecret = setupData.client_secret;
    }

    return new Response(
      JSON.stringify({
        clientSecret,
        customerId,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
