WITH cat AS (
  INSERT INTO public.categories (name, description, display_order) VALUES ('ملابس أطفال','أزياء عصرية للأطفال',1)
  RETURNING id
)
INSERT INTO public.products (name, description, details, price, offer_price, is_offer, image_url, category_id, stock, size_options, color_options)
SELECT p.name, p.description, p.details, p.price, p.offer_price, p.is_offer, p.image_url, cat.id, p.stock, p.sizes, p.colors
FROM (VALUES
  ('تيشيرت أطفال ملون','تيشيرت قطن 100% مريح للأطفال','قطن مصري - ألوان متعددة', 150::numeric, 120::numeric, true, 'https://images.unsplash.com/photo-1519278409-1f56fdda7fe5?w=800', 50, ARRAY['2','4','6','8','10'], ARRAY['أحمر','أزرق','أصفر']),
  ('فستان بناتي مزهر','فستان صيفي بناتي بطبعات زهور','قماش خفيف - مناسب للصيف', 280, NULL, false, 'https://images.unsplash.com/photo-1518831959646-742c3a14ebf7?w=800', 30, ARRAY['2','4','6','8'], ARRAY['وردي','أبيض','أصفر']),
  ('بدلة أولادي رياضية','طقم رياضي ولادي مريح','تيشيرت + بنطلون', 350, 299, true, 'https://images.unsplash.com/photo-1503944583220-79d8926ad5e2?w=800', 40, ARRAY['4','6','8','10','12'], ARRAY['كحلي','رمادي','أسود']),
  ('جاكيت شتوي أطفال','جاكيت دافئ بقلنسوة','مبطن بالفرو الناعم', 450, 399, true, 'https://images.unsplash.com/photo-1622290291468-a28f7a7dc6a8?w=800', 25, ARRAY['4','6','8','10'], ARRAY['أحمر','أزرق','وردي']),
  ('بيجاما أطفال قطن','بيجاما نوم قطنية ناعمة','قطعتين - رسومات كرتونية', 180, NULL, false, 'https://images.unsplash.com/photo-1622290319146-7b6f0d4ef3d4?w=800', 60, ARRAY['2','4','6','8','10'], ARRAY['أزرق','وردي','أخضر']),
  ('حذاء رياضي أطفال','سنيكرز رياضي مريح للأطفال','نعل مرن - خفيف الوزن', 320, 280, true, 'https://images.unsplash.com/photo-1514989940723-e8e51635b782?w=800', 35, ARRAY['24','26','28','30','32'], ARRAY['أبيض','أسود','وردي']),
  ('شورت جينز ولادي','شورت جينز كاجوال','جينز عالي الجودة', 200, NULL, false, 'https://images.unsplash.com/photo-1503944168849-8bf86875cf52?w=800', 45, ARRAY['4','6','8','10','12'], ARRAY['أزرق فاتح','أزرق غامق']),
  ('تنورة بناتي بكشكشة','تنورة قصيرة بكشكشة وردية','تول ناعم - بطانة قطن', 220, 190, true, 'https://images.unsplash.com/photo-1518806118471-f28b20a1d79d?w=800', 28, ARRAY['2','4','6','8'], ARRAY['وردي','أبيض','نعناعي']),
  ('قبعة شمس أطفال','قبعة قطنية بحواف عريضة','حماية من الشمس - قابلة للطي', 90, NULL, false, 'https://images.unsplash.com/photo-1622290291165-d341f1937c97?w=800', 80, ARRAY['Free'], ARRAY['أصفر','أزرق','وردي']),
  ('بلوزة شتوي صوف','بلوزة صوف دافئة بياقة عالية','صوف مخلوط - ناعم', 260, 220, true, 'https://images.unsplash.com/photo-1543854704-783ed8b88112?w=800', 32, ARRAY['4','6','8','10','12'], ARRAY['أحمر','رمادي','بيج'])
) AS p(name,description,details,price,offer_price,is_offer,image_url,stock,sizes,colors)
CROSS JOIN cat;