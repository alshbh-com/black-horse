import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, secret",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function s(v: any): string | null {
  if (v === null || v === undefined) return null;
  const x = String(v).trim();
  return x === "" ? null : x;
}
function n(v: any): number {
  const x = Number(v);
  return isFinite(x) ? x : 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ ok: false, error: "method not allowed" }), {
      status: 405, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const { data: integ } = await supabase
      .from("api_integrations").select("*").eq("id", "easyorders").maybeSingle();

    // Optional secret verification
    if (integ?.webhook_secret) {
      const provided = req.headers.get("secret") || req.headers.get("Secret") || "";
      if (provided !== integ.webhook_secret) {
        return new Response(JSON.stringify({ ok: false, error: "invalid secret" }), {
          status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const body = await req.json();

    // Handle status-change events: just update status if mapped
    if (body.event_type === "order-status-update" && body.order_id) {
      const { data: ord } = await supabase.from("orders").select("id")
        .eq("external_source", "easyorders").eq("external_order_id", String(body.order_id)).maybeSingle();
      if (ord) {
        await supabase.from("orders").update({ notes: `EasyOrders status: ${body.new_status}` }).eq("id", ord.id);
      }
      return new Response(JSON.stringify({ ok: true, type: "status-update" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const externalId = s(body.id) || s(body.order_id);
    if (!externalId) {
      return new Response(JSON.stringify({ ok: false, error: "missing order id" }), {
        status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Dedupe
    const { data: exists } = await supabase.from("orders").select("id")
      .eq("external_source", "easyorders").eq("external_order_id", externalId).maybeSingle();
    if (exists) {
      return new Response(JSON.stringify({ ok: true, duplicate: true }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const name = s(body.full_name) || s(body.name) || "عميل EasyOrders";
    const phone = s(body.phone) || "";
    const address = s(body.address) || "";
    const govName = s(body.government) || s(body.governorate) || "";
    const shipping = n(body.shipping_cost);
    const totalAmount = n(body.total_cost) || (n(body.cost) + shipping);

    // Customer upsert by phone
    let customerId: string | null = null;
    if (phone) {
      const { data: existingCust } = await supabase
        .from("customers").select("id").eq("phone", phone).maybeSingle();
      if (existingCust) {
        customerId = existingCust.id;
        await supabase.from("customers").update({ name, address, governorate: govName }).eq("id", customerId);
      } else {
        const { data: newCust } = await supabase
          .from("customers").insert({ name, phone, address, governorate: govName })
          .select("id").single();
        customerId = newCust?.id || null;
      }
    }

    let governorateId: string | null = null;
    if (govName) {
      const { data: gov } = await supabase
        .from("governorates").select("id").ilike("name", `%${govName}%`).maybeSingle();
      governorateId = gov?.id || null;
    }

    const items = Array.isArray(body.cart_items) ? body.cart_items : [];
    const itemsText = items.map((it: any) => {
      const pname = it?.product?.name || "منتج";
      const color = it?.variant?.variation_props?.find((p: any) => p.variation === "color")?.variation_prop || "";
      const size = it?.variant?.variation_props?.find((p: any) => p.variation === "size")?.variation_prop || "";
      const opts = [color, size].filter(Boolean).join(" / ");
      return `${pname}${opts ? " (" + opts + ")" : ""} × ${it.quantity}`;
    }).join("\n");

    const { data: newOrder, error: orderErr } = await supabase
      .from("orders").insert({
        customer_id: customerId,
        governorate_id: governorateId,
        status: "pending",
        shipping_cost: shipping,
        total_amount: totalAmount,
        notes: s(body.notes) || `EasyOrders - ${s(body.payment_method) || "cod"}`,
        order_details: itemsText || null,
        external_source: "easyorders",
        external_order_id: externalId,
      }).select("id").single();

    if (orderErr || !newOrder) {
      console.error("order insert error", orderErr);
      return new Response(JSON.stringify({ ok: false, error: orderErr?.message }), {
        status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (items.length > 0) {
      const rows = items.map((it: any) => {
        const color = it?.variant?.variation_props?.find((p: any) => p.variation === "color")?.variation_prop || null;
        const size = it?.variant?.variation_props?.find((p: any) => p.variation === "size")?.variation_prop || null;
        return {
          order_id: newOrder.id,
          product_details: it?.product?.name || "منتج",
          color, size,
          quantity: n(it.quantity) || 1,
          price: n(it.price),
        };
      });
      await supabase.from("order_items").insert(rows);
    }

    await supabase.from("api_integrations").update({
      last_sync_at: new Date().toISOString(),
      last_sync_status: "success",
      last_sync_message: `استلام طلب جديد ${externalId}`,
      imported_count: (integ?.imported_count || 0) + 1,
    }).eq("id", "easyorders");

    return new Response(JSON.stringify({ ok: true, order_id: newOrder.id }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e: any) {
    console.error("easyorders-webhook error", e);
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});