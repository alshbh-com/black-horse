
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS discount numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS order_details jsonb,
  ADD COLUMN IF NOT EXISTS payment_method text,
  ADD COLUMN IF NOT EXISTS governorate_id uuid REFERENCES public.governorates(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_orders_governorate ON public.orders(governorate_id);

ALTER TABLE public.delivery_agents
  ADD COLUMN IF NOT EXISTS serial_number text;

ALTER TABLE public.cashbox_transactions
  ADD COLUMN IF NOT EXISTS reason text,
  ADD COLUMN IF NOT EXISTS user_id uuid,
  ADD COLUMN IF NOT EXISTS username text;

CREATE OR REPLACE FUNCTION public.delete_old_activity_logs()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM public.activity_logs WHERE created_at < now() - interval '30 days';
END $$;

-- Set search_path on previously created functions to satisfy linter
ALTER FUNCTION public.set_updated_at() SET search_path = public;
ALTER FUNCTION public.orders_set_codes() SET search_path = public;
ALTER FUNCTION public.orders_status_change() SET search_path = public;
ALTER FUNCTION public.orders_after_status_change() SET search_path = public;
ALTER FUNCTION public.customers_bump_on_order() SET search_path = public;
ALTER FUNCTION public.ensure_daily_cashbox() SET search_path = public;
