INSERT INTO storage.buckets (id, name, public) VALUES ('products', 'products', true) ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Public read products bucket" ON storage.objects FOR SELECT USING (bucket_id = 'products');
CREATE POLICY "Public upload products bucket" ON storage.objects FOR INSERT WITH CHECK (bucket_id = 'products');
CREATE POLICY "Public update products bucket" ON storage.objects FOR UPDATE USING (bucket_id = 'products');
CREATE POLICY "Public delete products bucket" ON storage.objects FOR DELETE USING (bucket_id = 'products');