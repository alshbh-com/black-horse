ALTER TABLE public.api_integrations ADD COLUMN IF NOT EXISTS webhook_secret TEXT;

DO $$
BEGIN
  PERFORM cron.unschedule('easyorders-sync-every-2-min');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;