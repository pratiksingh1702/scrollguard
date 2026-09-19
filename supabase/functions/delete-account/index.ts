// Supabase Edge Function: delete-account
// Cascades deletion of all user records, charges, and Stripe customer data

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

    // User client to verify caller
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

    // Service role client to perform admin deletion
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    // 1. Fetch any Stripe customer IDs to clean up on Stripe
    const { data: contracts } = await adminClient
      .from("contracts")
      .select("stripe_customer_id")
      .eq("user_id", user.id);

    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
    if (stripeSecret && contracts && contracts.length > 0) {
      for (const contract of contracts) {
        if (contract.stripe_customer_id) {
          try {
            await fetch(`https://api.stripe.com/v1/customers/${contract.stripe_customer_id}`, {
              method: "DELETE",
              headers: { Authorization: `Bearer ${stripeSecret}` },
            });
          } catch (stripeErr) {
            console.error("Stripe customer deletion warning:", stripeErr);
          }
        }
      }
    }

    // 2. Delete user from auth.users (cascades via foreign keys across all tables)
    const { error: deleteError } = await adminClient.auth.admin.deleteUser(user.id);
    if (deleteError) {
      return new Response(JSON.stringify({ error: deleteError.message }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ success: true, message: "User account and all data deleted successfully" }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
