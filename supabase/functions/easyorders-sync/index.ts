import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.0";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

function pickString(obj: any, keys: string[]): string | null {
  for (const k of keys) {
    const v = k.split(".").reduce((a: any, p: string) => (a ? a[p] : undefined), obj);
    if (v !== undefined && v !== null && String(v).trim() !== "") return String(v);
  }
  return null;
}
function pickNumber(obj: any, keys: string[]): number {
  for (const k of keys) {
    const v = k.split(".").reduce((a: any, p: string) => (a ? a[p] : undefined), obj);
    if (v !== undefined && v !== null && !isNaN(Number(v))) return Number(v);
  }
  return 0;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  try {
    const { data: integ } = await supabase
      .from("api_integrations")
      .select("*")
      .eq("id", "easyorders")
      .maybeSingle();

    if (!integ || !integ.enabled || !integ.api_key || !integ.api_url) {
      return new Response(JSON.stringify({ ok: false, skipped: true, reason: "integration disabled or missing key" }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // Fetch orders from EasyOrders
    const url = new URL(integ.api_url);
    if (integ.last_sync_at) url.searchParams.set("from", new Date(integ.last_sync_at).toISOString());
    const resp = await fetch(url.toString(), {
      headers: {
        "Api-Key": integ.api_key,
        "Authorization": `Bearer ${integ.api_key}`,
        "Accept": "application/json",
      },
    });

    if (!resp.ok) {
      const text = await resp.text();
      await supabase.from("api_integrations").update({
        last_sync_at: new Date().toISOString(),
        last_sync_status: "error",
        last_sync_message: `HTTP ${resp.status}: ${text.slice(0, 300)}`,
      }).eq("id", "easyorders");
      return new Response(JSON.stringify({ ok: false, status: resp.status, error: text }), {
        status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const json = await resp.json();
    const list: any[] = Array.isArray(json) ? json : (json.data || json.orders || json.results || []);

    let imported = 0;
    let skipped = 0;

    for (const o of list) {
      const externalId = pickString(o, ["id", "order_id", "uuid", "reference"]);
      if (!externalId) { skipped++; continue; }

      // dedupe
      const { data: exists } = await supabase
        .from("orders")
        .select("id")
        .eq("external_source", "easyorders")
        .eq("external_order_id", externalId)
        .maybeSingle();
      if (exists) { skipped++; continue; }

      const phone = pickString(o, ["customer_phone", "phone", "customer.phone", "shipping.phone"]) || "";
      const name = pickString(o, ["customer_name", "name", "customer.name", "shipping.name"]) || "عميل EasyOrders";
      const address = pickString(o, ["customer_address", "address", "shipping.address", "shipping_address"]) || "";
      const govName = pickString(o, ["governorate", "city", "shipping.city", "shipping.governorate"]) || "";
      const notes = pickString(o, ["notes", "note", "comments"]) || "";
      const shipping = pickNumber(o, ["shipping_cost", "shipping", "shipping_fees", "delivery_cost"]);
      const totalAmount = pickNumber(o, ["total", "total_amount", "grand_total", "amount"]);

      // upsert customer by phone
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

      // governorate match by name
      let governorateId: string | null = null;
      if (govName) {
        const { data: gov } = await supabase
          .from("governorates").select("id").ilike("name", govName).maybeSingle();
        governorateId = gov?.id || null;
      }

      const { data: newOrder, error: orderErr } = await supabase
        .from("orders")
        .insert({
          customer_id: customerId,
          governorate_id: governorateId,
          status: "pending",
          shipping_cost: shipping,
          total_amount: totalAmount,
          notes,
          order_details: pickString(o, ["order_details", "details"]) || null,
          external_source: "easyorders",
          external_order_id: externalId,
        })
        .select("id")
        .single();

      if (orderErr || !newOrder) { skipped++; continue; }

      const items: any[] = o.items || o.products || o.line_items || [];
      if (Array.isArray(items) && items.length > 0) {
        const rows = items.map((it: any) => ({
          order_id: newOrder.id,
          product_details: pickString(it, ["name", "product_name", "title"]) || "منتج",
          color: pickString(it, ["color", "variant.color"]),
          size: pickString(it, ["size", "variant.size"]),
          quantity: pickNumber(it, ["quantity", "qty"]) || 1,
          price: pickNumber(it, ["price", "unit_price", "total"]),
        }));
        await supabase.from("order_items").insert(rows);
      }

      imported++;
    }

    await supabase.from("api_integrations").update({
      last_sync_at: new Date().toISOString(),
      last_sync_status: "success",
      last_sync_message: `استيراد ${imported} طلب جديد، تخطي ${skipped}`,
      imported_count: (integ.imported_count || 0) + imported,
    }).eq("id", "easyorders");

    return new Response(JSON.stringify({ ok: true, imported, skipped, total: list.length }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (e: any) {
    console.error("easyorders-sync error", e);
    await supabase.from("api_integrations").update({
      last_sync_at: new Date().toISOString(),
      last_sync_status: "error",
      last_sync_message: String(e?.message || e).slice(0, 500),
    }).eq("id", "easyorders");
    return new Response(JSON.stringify({ ok: false, error: String(e?.message || e) }), {
      status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});