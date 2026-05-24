
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS is_offer boolean NOT NULL DEFAULT false;

-- Convert jsonb -> text[] (tables are empty so simple cast via NULL is fine)
ALTER TABLE public.products ALTER COLUMN size_options DROP DEFAULT;
ALTER TABLE public.products ALTER COLUMN size_options TYPE text[] USING NULL;
ALTER TABLE public.products ALTER COLUMN color_options DROP DEFAULT;
ALTER TABLE public.products ALTER COLUMN color_options TYPE text[] USING NULL;

ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

ALTER TABLE public.delivery_agents
  ADD COLUMN IF NOT EXISTS serial_number text,
  ADD COLUMN IF NOT EXISTS total_paid numeric NOT NULL DEFAULT 0;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS modified_amount numeric NOT NULL DEFAULT 0;

ALTER TABLE public.statistics
  ADD COLUMN IF NOT EXISTS last_reset timestamptz;

CREATE OR REPLACE FUNCTION public.reset_order_sequence()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM setval('public.orders_order_number_seq', 1, false);
END;
$$;
