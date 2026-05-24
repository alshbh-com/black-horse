
INSERT INTO storage.buckets (id, name, public)
VALUES 
  ('products', 'products', true),
  ('categories', 'categories', true),
  ('logos', 'logos', true)
ON CONFLICT (id) DO UPDATE SET public = true;

CREATE POLICY "public_read_products" ON storage.objects FOR SELECT USING (bucket_id = 'products');
CREATE POLICY "public_write_products" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'products');
CREATE POLICY "public_update_products" ON storage.objects FOR UPDATE USING (bucket_id = 'products');
CREATE POLICY "public_delete_products" ON storage.objects FOR DELETE USING (bucket_id = 'products');

CREATE POLICY "public_read_categories" ON storage.objects FOR SELECT USING (bucket_id = 'categories');
CREATE POLICY "public_write_categories" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'categories');
CREATE POLICY "public_update_categories" ON storage.objects FOR UPDATE USING (bucket_id = 'categories');
CREATE POLICY "public_delete_categories" ON storage.objects FOR DELETE USING (bucket_id = 'categories');

CREATE POLICY "public_read_logos" ON storage.objects FOR SELECT USING (bucket_id = 'logos');
CREATE POLICY "public_write_logos" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'logos');
CREATE POLICY "public_update_logos" ON storage.objects FOR UPDATE USING (bucket_id = 'logos');
CREATE POLICY "public_delete_logos" ON storage.objects FOR DELETE USING (bucket_id = 'logos');
