// Supabase Edge Function: stripe-webhook
// Handles asynchronous Stripe events for PaymentIntents and disputes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  try {
    const adminClient = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "",
      { auth: { persistSession: false } }
    );

    const payload = await req.text();
    const event = JSON.parse(payload);

    switch (event.type) {
      case "payment_intent.succeeded": {
        const paymentIntent = event.data.object;
        await adminClient
          .from("charges")
          .update({
            status: "succeeded",
            failure_reason: null,
          })
          .eq("stripe_payment_intent_id", paymentIntent.id);
        break;
      }

      case "payment_intent.payment_failed": {
        const paymentIntent = event.data.object;
        const failureMessage =
          paymentIntent.last_payment_error?.message ?? "Payment failed";

        const { data: charge } = await adminClient
          .from("charges")
          .update({
            status: "failed",
            failure_reason: failureMessage,
          })
          .eq("stripe_payment_intent_id", paymentIntent.id)
          .select("contract_id")
          .maybeSingle();

        if (charge) {
          // Check failure count
          const { count } = await adminClient
            .from("charges")
            .select("*", { count: "exact", head: true })
            .eq("contract_id", charge.contract_id)
            .eq("status", "failed");

          if ((count ?? 0) >= 3) {
            await adminClient
              .from("contracts")
              .update({ status: "paused" })
              .eq("id", charge.contract_id);
          }
        }
        break;
      }

      case "charge.dispute.created": {
        const dispute = event.data.object;
        const paymentIntentId = dispute.payment_intent;
        if (paymentIntentId) {
          await adminClient
            .from("charges")
            .update({
              failure_reason: `Dispute opened: ${dispute.reason}`,
            })
            .eq("stripe_payment_intent_id", paymentIntentId);
        }
        break;
      }
    }

    return new Response(JSON.stringify({ received: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }
});
