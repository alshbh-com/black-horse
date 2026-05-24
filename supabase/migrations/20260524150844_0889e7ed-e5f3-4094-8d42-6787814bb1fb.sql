
CREATE TABLE IF NOT EXISTS public.api_integrations (
  id text PRIMARY KEY,
  provider text NOT NULL,
  api_key text,
  api_url text,
  enabled boolean NOT NULL DEFAULT false,
  last_sync_at timestamptz,
  last_sync_status text,
  last_sync_message text,
  imported_count integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.api_integrations ENABLE ROW LEVEL SECURITY;
CREATE POLICY "public_all_api_integrations" ON public.api_integrations FOR ALL USING (true) WITH CHECK (true);

INSERT INTO public.api_integrations (id, provider, api_url)
VALUES ('easyorders','easyorders','https://api.easy-orders.net/api/v1/external-app-orders')
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS external_order_id text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS external_source text;
CREATE UNIQUE INDEX IF NOT EXISTS orders_external_unique ON public.orders (external_source, external_order_id) WHERE external_order_id IS NOT NULL;

CREATE EXTENSION IF NOT EXISTS pg_cron;
CREATE EXTENSION IF NOT EXISTS pg_net;
