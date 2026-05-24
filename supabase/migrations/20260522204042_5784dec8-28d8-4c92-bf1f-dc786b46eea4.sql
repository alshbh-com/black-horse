
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS modified_amount numeric(12,2);

ALTER TABLE public.orders
  ALTER COLUMN order_details TYPE text USING order_details::text;

ALTER TABLE public.products
  ALTER COLUMN size_options DROP DEFAULT,
  ALTER COLUMN size_options TYPE text[] USING ARRAY[]::text[],
  ALTER COLUMN size_options SET DEFAULT ARRAY[]::text[];

ALTER TABLE public.products
  ALTER COLUMN color_options DROP DEFAULT,
  ALTER COLUMN color_options TYPE text[] USING ARRAY[]::text[],
  ALTER COLUMN color_options SET DEFAULT ARRAY[]::text[];

-- quantity_pricing stays jsonb (it's structured)

CREATE OR REPLACE FUNCTION public.reset_order_sequence()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM setval('public.order_number_seq', 1000, false);
END $$;
