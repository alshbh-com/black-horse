
-- ============ ENUMS ============
DO $$ BEGIN
  CREATE TYPE public.order_status AS ENUM (
    'pending','processing','shipped','delivered','delivered_with_modification',
    'returned','return_no_shipping','cancelled','agent_deleted','failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============ COMMON updated_at fn ============
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;

-- ============ ADMIN AUTH ============
CREATE TABLE public.admin_users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  username text NOT NULL,
  password text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_admin_users_password ON public.admin_users(password);

CREATE TABLE public.admin_user_permissions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.admin_users(id) ON DELETE CASCADE,
  permission text NOT NULL,
  permission_type text NOT NULL DEFAULT 'view',
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, permission)
);

CREATE TABLE public.system_passwords (
  id text PRIMARY KEY,
  password text NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.app_settings (
  id text PRIMARY KEY,
  active_theme text DEFAULT 'default',
  active_template text DEFAULT 'default',
  platform_name text DEFAULT 'Family Fashion',
  invoice_name text DEFAULT 'Family Fashion',
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.offices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  logo_url text,
  watermark_name text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
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
CREATE INDEX idx_activity_logs_created ON public.activity_logs(created_at DESC);

-- ============ CATALOG ============
CREATE TABLE public.categories (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  image_url text,
  display_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.products (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  details text,
  price numeric(12,2) NOT NULL DEFAULT 0,
  offer_price numeric(12,2),
  is_offer boolean NOT NULL DEFAULT false,
  image_url text,
  category_id uuid REFERENCES public.categories(id) ON DELETE SET NULL,
  stock int NOT NULL DEFAULT 0,
  size_options jsonb DEFAULT '[]'::jsonb,
  color_options jsonb DEFAULT '[]'::jsonb,
  quantity_pricing jsonb DEFAULT '[]'::jsonb,
  display_order int NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_products_category ON public.products(category_id);

CREATE TABLE public.product_images (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
  image_url text NOT NULL,
  display_order int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.product_color_variants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id) ON DELETE CASCADE,
  color text NOT NULL,
  image_url text,
  stock int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ GEO ============
CREATE TABLE public.governorates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE,
  shipping_cost numeric(12,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ CUSTOMERS / AGENTS ============
CREATE TABLE public.customers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text NOT NULL UNIQUE,
  phone2 text,
  address text,
  governorate text,
  governorate_id uuid REFERENCES public.governorates(id) ON DELETE SET NULL,
  total_orders int NOT NULL DEFAULT 0,
  total_sales numeric(12,2) NOT NULL DEFAULT 0,
  last_reset timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.delivery_agents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  phone text,
  code text,
  total_owed numeric(12,2) NOT NULL DEFAULT 0,
  total_paid numeric(12,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- ============ ORDERS ============
CREATE SEQUENCE IF NOT EXISTS public.order_number_seq START 1000;

CREATE TABLE public.orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_number int NOT NULL UNIQUE DEFAULT nextval('public.order_number_seq'),
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  total_amount numeric(12,2) NOT NULL DEFAULT 0,
  shipping_cost numeric(12,2) NOT NULL DEFAULT 0,
  agent_shipping_cost numeric(12,2) NOT NULL DEFAULT 0,
  status public.order_status NOT NULL DEFAULT 'pending',
  notes text,
  assigned_at timestamptz,
  payment_date timestamptz,
  tracking_code text UNIQUE,
  barcode_value text,
  qr_value text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_orders_status ON public.orders(status);
CREATE INDEX idx_orders_agent ON public.orders(delivery_agent_id);
CREATE INDEX idx_orders_customer ON public.orders(customer_id);
CREATE INDEX idx_orders_assigned_at ON public.orders(assigned_at DESC);

CREATE TABLE public.order_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  quantity int NOT NULL DEFAULT 1,
  price numeric(12,2) NOT NULL DEFAULT 0,
  color text,
  size text,
  product_details jsonb,
  custom_details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.returns (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  return_amount numeric(12,2) NOT NULL DEFAULT 0,
  modified_amount numeric(12,2),
  returned_items jsonb,
  total_quantity int,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ FINANCE ============
CREATE TABLE public.agent_payments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  amount numeric(12,2) NOT NULL DEFAULT 0,
  payment_type text NOT NULL DEFAULT 'order',
  notes text,
  payment_date timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_agent_payments_agent ON public.agent_payments(delivery_agent_id);
CREATE INDEX idx_agent_payments_order ON public.agent_payments(order_id);

CREATE TABLE public.agent_daily_closings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_agent_id uuid REFERENCES public.delivery_agents(id) ON DELETE SET NULL,
  closing_date date NOT NULL,
  net_amount numeric(12,2) NOT NULL DEFAULT 0,
  serial_number int,
  closed_by uuid,
  closed_by_username text,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.cashbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  opening_balance numeric(12,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.cashbox_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cashbox_id uuid REFERENCES public.cashbox(id) ON DELETE CASCADE,
  type text NOT NULL,
  amount numeric(12,2) NOT NULL DEFAULT 0,
  description text,
  payment_method text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.treasury (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type text,
  amount numeric(12,2) NOT NULL DEFAULT 0,
  description text,
  category text,
  balance numeric(12,2),
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ STATS / ANALYTICS ============
CREATE TABLE public.statistics (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  total_orders int NOT NULL DEFAULT 0,
  total_sales numeric(12,2) NOT NULL DEFAULT 0,
  last_reset timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.analytics_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid REFERENCES public.products(id) ON DELETE SET NULL,
  event text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ SCAN ============
CREATE TABLE public.scan_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  username text,
  started_at timestamptz NOT NULL DEFAULT now(),
  ended_at timestamptz,
  total_scanned int NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'active'
);

CREATE TABLE public.scan_session_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id uuid REFERENCES public.scan_sessions(id) ON DELETE CASCADE,
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  scanned_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.scan_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid,
  username text,
  order_id uuid REFERENCES public.orders(id) ON DELETE SET NULL,
  action text NOT NULL,
  old_value text,
  new_value text,
  session_id uuid REFERENCES public.scan_sessions(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- ============ updated_at triggers ============
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY['admin_users','app_settings','offices','categories','products',
    'customers','delivery_agents','orders']) LOOP
    EXECUTE format('CREATE TRIGGER trg_%I_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.set_updated_at()', t, t);
  END LOOP;
END $$;

-- ============ Orders: tracking_code + barcode/qr autogen ============
CREATE OR REPLACE FUNCTION public.orders_set_codes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.tracking_code IS NULL THEN
    NEW.tracking_code := 'TRK-' || lpad(NEW.order_number::text, 6, '0');
  END IF;
  IF NEW.barcode_value IS NULL THEN NEW.barcode_value := NEW.tracking_code; END IF;
  IF NEW.qr_value IS NULL THEN NEW.qr_value := NEW.tracking_code; END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_orders_set_codes BEFORE INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.orders_set_codes();

-- ============ Orders status change: financial + agent logic ============
CREATE OR REPLACE FUNCTION public.orders_status_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE net numeric;
BEGIN
  -- Reverting to pending/processing clears the agent
  IF NEW.status IN ('pending','processing') AND (OLD.status IS DISTINCT FROM NEW.status) THEN
    NEW.delivery_agent_id := NULL;
    NEW.assigned_at := NULL;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_orders_status_change BEFORE UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.orders_status_change();

CREATE OR REPLACE FUNCTION public.orders_after_status_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE net numeric;
BEGIN
  -- Became delivered: create agent payment + update owed
  IF NEW.status IN ('delivered','delivered_with_modification')
     AND (OLD.status IS DISTINCT FROM NEW.status)
     AND NEW.delivery_agent_id IS NOT NULL THEN
    net := COALESCE(NEW.total_amount,0) + COALESCE(NEW.shipping_cost,0) - COALESCE(NEW.agent_shipping_cost,0);
    INSERT INTO public.agent_payments(delivery_agent_id, order_id, amount, payment_type, payment_date, notes)
    VALUES (NEW.delivery_agent_id, NEW.id, net, 'order', now(), 'تسليم طلب #' || NEW.order_number);
    UPDATE public.delivery_agents SET total_owed = COALESCE(total_owed,0) + net
    WHERE id = NEW.delivery_agent_id;
  END IF;

  -- Reverted FROM delivered: delete payment + reverse owed
  IF OLD.status IN ('delivered','delivered_with_modification')
     AND NEW.status NOT IN ('delivered','delivered_with_modification')
     AND OLD.delivery_agent_id IS NOT NULL THEN
    DELETE FROM public.agent_payments
      WHERE order_id = OLD.id AND payment_type = 'order'
      RETURNING amount INTO net;
    IF net IS NOT NULL THEN
      UPDATE public.delivery_agents SET total_owed = COALESCE(total_owed,0) - net
      WHERE id = OLD.delivery_agent_id;
    END IF;
  END IF;

  RETURN NEW;
END $$;
CREATE TRIGGER trg_orders_after_status_change AFTER UPDATE OF status ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.orders_after_status_change();

-- ============ Customer stats trigger on order create ============
CREATE OR REPLACE FUNCTION public.customers_bump_on_order()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.customer_id IS NOT NULL THEN
    UPDATE public.customers
       SET total_orders = COALESCE(total_orders,0) + 1,
           total_sales = COALESCE(total_sales,0) + COALESCE(NEW.total_amount,0)
     WHERE id = NEW.customer_id;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_customers_bump AFTER INSERT ON public.orders
FOR EACH ROW EXECUTE FUNCTION public.customers_bump_on_order();

-- ============ Daily cashbox auto-create ============
CREATE OR REPLACE FUNCTION public.ensure_daily_cashbox()
RETURNS void LANGUAGE plpgsql AS $$
DECLARE today_name text;
BEGIN
  today_name := 'خزنة ' || to_char(now(), 'YYYY-MM-DD');
  INSERT INTO public.cashbox(name, opening_balance, is_active)
  SELECT today_name, 0, true
  WHERE NOT EXISTS (SELECT 1 FROM public.cashbox WHERE name = today_name);
END $$;

-- ============ RLS: enable + public-permissive policies ============
DO $$
DECLARE t text;
BEGIN
  FOR t IN SELECT unnest(ARRAY[
    'admin_users','admin_user_permissions','system_passwords','app_settings','offices','activity_logs',
    'categories','products','product_images','product_color_variants','governorates',
    'customers','delivery_agents','orders','order_items','returns',
    'agent_payments','agent_daily_closings','cashbox','cashbox_transactions','treasury',
    'statistics','analytics_events','scan_sessions','scan_session_items','scan_logs'
  ]) LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t);
    EXECUTE format('CREATE POLICY "Public read %I" ON public.%I FOR SELECT USING (true)', t, t);
    EXECUTE format('CREATE POLICY "Public write %I" ON public.%I FOR INSERT WITH CHECK (true)', t, t);
    EXECUTE format('CREATE POLICY "Public update %I" ON public.%I FOR UPDATE USING (true) WITH CHECK (true)', t, t);
    EXECUTE format('CREATE POLICY "Public delete %I" ON public.%I FOR DELETE USING (true)', t, t);
  END LOOP;
END $$;

-- ============ SEED: owner user + permissions + system passwords + settings ============
INSERT INTO public.app_settings(id, active_theme, active_template, platform_name, invoice_name)
VALUES ('main','default','default','Family Fashion','Family Fashion');

INSERT INTO public.system_passwords(id, password) VALUES
  ('master','01013701405'),
  ('payment','01013701405'),
  ('admin_delete','01013701405'),
  ('treasury_password','01013701405');

INSERT INTO public.statistics(total_orders, total_sales) VALUES (0,0);

WITH new_owner AS (
  INSERT INTO public.admin_users(username, password, is_active)
  VALUES ('المالك', '01278006248', true)
  RETURNING id
)
INSERT INTO public.admin_user_permissions(user_id, permission, permission_type)
SELECT id, perm, 'edit' FROM new_owner,
  unnest(ARRAY[
    'dashboard','orders','agents','agent_orders','all_orders','products','categories',
    'customers','governorates','offices','invoices','cashbox','treasury','statistics',
    'activity_logs','user_management','appearance','settings','reset_data','barcode_scanner'
  ]) AS perm;
