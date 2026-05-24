
-- =========================================================
-- 1. Settings + system passwords
-- =========================================================
CREATE TABLE public.app_settings (
  id text PRIMARY KEY DEFAULT 'main',
  active_theme text NOT NULL DEFAULT 'blue-default',
  active_template text NOT NULL DEFAULT 'classic',
  platform_name text NOT NULL DEFAULT 'Family Fashion',
  invoice_name text NOT NULL DEFAULT 'Family Fashion',
  logo_url text,
  watermark_name text,
  active_office_id uuid,
  extra jsonb DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.app_settings (id) VALUES ('main');

CREATE TABLE public.system_passwords (
  id text PRIMARY KEY,
  password text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO public.system_passwords (id, password) VALUES
  ('master', '01013701405'),
  ('payment', '01013701405'),
  ('admin_delete', '01013701405'),
  ('treasury_password', '01013701405');

-- =========================================================
-- 2. Admin users + permissions + activity logs
-- =========================================================
CREATE TABLE public.admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL UNIQUE,
  password text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.admin_user_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
  permission text NOT NULL,
  permission_type text NOT NULL DEFAULT 'view',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, permission)
);

CREATE TABLE public.activity_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  username text,
  action text NOT NULL,
  section text,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_activity_logs_created_at ON public.activity_logs(created_at DESC);

CREATE OR REPLACE FUNCTION public.delete_old_activity_logs()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.activity_logs WHERE created_at < now() - interval '3 days';
$$;

-- =========================================================
-- 3. Offices / Governorates / Categories
-- =========================================================
CREATE TABLE public.offices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  logo_url text,
  watermark_name text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.governorates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  shipping_cost numeric NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  image_url text,
  display_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- 4. Products
-- =========================================================
CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  details text,
  image_url text,
  price numeric NOT NULL DEFAULT 0,
  offer_price numeric,
  stock int NOT NULL DEFAULT 0,
  size_options jsonb,
  color_options jsonb,
  quantity_pricing jsonb,
  category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.product_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.product_color_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  color text NOT NULL,
  image_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- 5. Customers
-- =========================================================
CREATE TABLE public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text NOT NULL UNIQUE,
  phone2 text,
  address text,
  governorate text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- 6. Delivery agents
-- =========================================================
CREATE TABLE public.delivery_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text,
  total_owed numeric NOT NULL DEFAULT 0,
  shipping_cost numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- 7. Orders + items + status history
-- =========================================================
CREATE SEQUENCE IF NOT EXISTS public.orders_order_number_seq START 1;

CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number bigint NOT NULL UNIQUE DEFAULT nextval('public.orders_order_number_seq'),
  tracking_code text UNIQUE,
  barcode_value text,
  qr_value text,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  governorate_id uuid REFERENCES public.governorates(id) ON DELETE SET NULL,
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  total_amount numeric NOT NULL DEFAULT 0,
  shipping_cost numeric NOT NULL DEFAULT 0,
  agent_shipping_cost numeric NOT NULL DEFAULT 0,
  discount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  notes text,
  order_details text,
  assigned_at timestamptz,
  payment_date date,
  agent_deleted boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER SEQUENCE public.orders_order_number_seq OWNED BY public.orders.order_number;
CREATE INDEX idx_orders_customer ON public.orders(customer_id);
CREATE INDEX idx_orders_agent ON public.orders(delivery_agent_id);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_created_at ON public.orders(created_at DESC);

CREATE TABLE public.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  quantity int NOT NULL DEFAULT 1,
  price numeric NOT NULL DEFAULT 0,
  size text,
  color text,
  product_details text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_order_items_order ON public.order_items(order_id);

CREATE TABLE public.order_status_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  old_status text,
  new_status text NOT NULL,
  changed_by uuid,
  changed_by_username text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Auto-generate tracking_code from order_number
CREATE OR REPLACE FUNCTION public.set_order_tracking()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF NEW.tracking_code IS NULL THEN
    NEW.tracking_code := 'TRK-' || LPAD(NEW.order_number::text, 6, '0');
  END IF;
  IF NEW.barcode_value IS NULL THEN
    NEW.barcode_value := NEW.tracking_code;
  END IF;
  IF NEW.qr_value IS NULL THEN
    NEW.qr_value := NEW.tracking_code;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_orders_tracking
BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.set_order_tracking();

-- Auto-log status changes
CREATE OR REPLACE FUNCTION public.log_order_status_change()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status IS DISTINCT FROM OLD.status THEN
    INSERT INTO public.order_status_history (order_id, old_status, new_status)
    VALUES (NEW.id, OLD.status, NEW.status);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_orders_status_history
AFTER UPDATE ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.log_order_status_change();

-- updated_at helper
CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;
CREATE TRIGGER trg_orders_updated_at BEFORE UPDATE ON public.orders FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_products_updated_at BEFORE UPDATE ON public.products FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_customers_updated_at BEFORE UPDATE ON public.customers FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_agents_updated_at BEFORE UPDATE ON public.delivery_agents FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_app_settings_updated_at BEFORE UPDATE ON public.app_settings FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_offices_updated_at BEFORE UPDATE ON public.offices FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_govs_updated_at BEFORE UPDATE ON public.governorates FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_categories_updated_at BEFORE UPDATE ON public.categories FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_admin_users_updated_at BEFORE UPDATE ON public.admin_users FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER trg_system_passwords_updated_at BEFORE UPDATE ON public.system_passwords FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

-- =========================================================
-- 8. Returns
-- =========================================================
CREATE TABLE public.returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  return_amount numeric NOT NULL DEFAULT 0,
  returned_items jsonb,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- 9. Agent payments + daily closings
-- =========================================================
CREATE TABLE public.agent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_agent_id uuid NOT NULL REFERENCES public.delivery_agents(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  amount numeric NOT NULL DEFAULT 0,
  payment_type text NOT NULL DEFAULT 'payment',
  payment_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Africa/Cairo')::date,
  notes text,
  assigned_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_agent_payments_agent ON public.agent_payments(delivery_agent_id);
CREATE INDEX idx_agent_payments_date ON public.agent_payments(payment_date);

CREATE TABLE public.agent_daily_closings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_agent_id uuid NOT NULL REFERENCES public.delivery_agents(id) ON DELETE CASCADE,
  closing_date date NOT NULL,
  net_amount numeric NOT NULL DEFAULT 0,
  closed_by uuid,
  closed_by_username text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (delivery_agent_id, closing_date)
);

-- =========================================================
-- 10. Cashbox + treasury
-- =========================================================
CREATE TABLE public.cashbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  opening_balance numeric NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cashbox_id uuid NOT NULL REFERENCES public.cashbox(id) ON DELETE CASCADE,
  type text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  reason text,
  description text,
  payment_method text DEFAULT 'cash',
  user_id uuid,
  username text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_cashbox_tx_cashbox ON public.cashbox_transactions(cashbox_id);

CREATE TABLE public.treasury (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text NOT NULL,
  amount numeric NOT NULL DEFAULT 0,
  description text,
  category text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- 11. Statistics + analytics
-- =========================================================
CREATE TABLE public.statistics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  total_sales numeric NOT NULL DEFAULT 0,
  total_orders int NOT NULL DEFAULT 0,
  snapshot_date date NOT NULL DEFAULT (now() AT TIME ZONE 'Africa/Cairo')::date,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_type text NOT NULL,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  metadata jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- 12. Scanner
-- =========================================================
CREATE TABLE public.scan_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  username text,
  status text NOT NULL DEFAULT 'active',
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  total_scanned int NOT NULL DEFAULT 0
);

CREATE TABLE public.scan_session_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid NOT NULL REFERENCES public.scan_sessions(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  scanned_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.scan_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  username text,
  session_id uuid REFERENCES public.scan_sessions(id) ON DELETE SET NULL,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  action text NOT NULL,
  old_value text,
  new_value text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =========================================================
-- RLS: Enable on all, allow public access (no Supabase Auth in this system)
-- =========================================================
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'app_settings','system_passwords','admin_users','admin_user_permissions','activity_logs',
    'offices','governorates','categories','products','product_images','product_color_variants',
    'customers','delivery_agents','orders','order_items','order_status_history','returns',
    'agent_payments','agent_daily_closings','cashbox','cashbox_transactions','treasury',
    'statistics','analytics_events','scan_sessions','scan_session_items','scan_logs'
  ]) LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY "public_all_%s" ON public.%I FOR ALL USING (true) WITH CHECK (true)', t, t);
  END LOOP;
END $$;

-- =========================================================
-- Realtime
-- =========================================================
ALTER TABLE public.orders REPLICA IDENTITY FULL;
ALTER TABLE public.scan_session_items REPLICA IDENTITY FULL;
ALTER TABLE public.app_settings REPLICA IDENTITY FULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.orders;
ALTER PUBLICATION supabase_realtime ADD TABLE public.scan_session_items;
ALTER PUBLICATION supabase_realtime ADD TABLE public.app_settings;
