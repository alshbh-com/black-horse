DELETE FROM public.admin_user_permissions 
WHERE user_id IN (SELECT id FROM public.admin_users WHERE username='admin');

INSERT INTO public.admin_user_permissions (user_id, permission, permission_type)
SELECT u.id, p.permission, 'edit'
FROM public.admin_users u
CROSS JOIN (VALUES 
  ('orders'),('products'),('categories'),('customers'),
  ('agents'),('agent_orders'),('agent_payments'),('governorates'),
  ('statistics'),('invoices'),('all_orders'),('settings'),
  ('reset_data'),('user_management'),('cashbox'),('treasury'),
  ('barcode_scanner')
) AS p(permission)
WHERE u.username='admin';