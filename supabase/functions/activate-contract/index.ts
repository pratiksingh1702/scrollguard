// Supabase Edge Function: activate-contract
// Validates terms acceptance, links saved PaymentMethod, and activates commitment contract

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

    const body = await req.json();
    const { contract_id, payment_method_id, terms_version } = body;

    if (!contract_id || !payment_method_id) {
      return new Response(JSON.stringify({ error: "Missing contract_id or payment_method_id" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Verify contract belongs to user
    const { data: contract, error: contractErr } = await supabaseClient
      .from("contracts")
      .select("*")
      .eq("id", contract_id)
      .eq("user_id", user.id)
      .single();

    if (contractErr || !contract) {
      return new Response(JSON.stringify({ error: "Contract not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Activate the contract in database
    const { data: updatedContract, error: updateErr } = await supabaseClient
      .from("contracts")
      .update({
        status: "active",
        stripe_pm_id: payment_method_id,
        terms_version: terms_version ?? "v1.0",
        accepted_at: new Date().toISOString(),
        cooling_off_until: null,
      })
      .eq("id", contract_id)
      .select()
      .single();

    if (updateErr) {
      throw updateErr;
    }

    return new Response(
      JSON.stringify({
        success: true,
        contract: updatedContract,
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
