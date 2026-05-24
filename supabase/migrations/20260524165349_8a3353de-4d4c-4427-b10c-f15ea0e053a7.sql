INSERT INTO public.api_integrations (id, provider, api_key, api_url, enabled)
VALUES ('easyorders','easyorders','e39b3643-f563-4013-ada0-bdb7bc19efdd','https://api.easy-orders.net/api/v1/external-app-orders', true)
ON CONFLICT (id) DO UPDATE SET api_key = EXCLUDED.api_key, api_url = EXCLUDED.api_url, enabled = true, updated_at = now();