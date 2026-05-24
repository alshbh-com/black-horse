UPDATE public.app_settings SET platform_name='Black Horse', invoice_name='Black Horse', watermark_name='Black Horse' WHERE id='main';

INSERT INTO public.admin_users (username, password, is_active) 
SELECT 'admin', '01278006248', true
WHERE NOT EXISTS (SELECT 1 FROM public.admin_users WHERE username='admin');

UPDATE public.admin_users SET password='01278006248', is_active=true WHERE username='admin';

INSERT INTO public.admin_user_permissions (user_id, permission, permission_type)
SELECT u.id, p.permission, 'edit'
FROM public.admin_users u
CROSS JOIN (VALUES 
  ('dashboard'),('orders'),('products'),('categories'),('customers'),
  ('agents'),('governorates'),('offices'),('cashbox'),('treasury'),
  ('statistics'),('invoices'),('scanner'),('users'),('appearance'),
  ('activity_logs'),('reset_data'),('settings')
) AS p(permission)
WHERE u.username='admin'
ON CONFLICT DO NOTHING;