
SELECT cron.unschedule('easyorders-sync-every-2-min') WHERE EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'easyorders-sync-every-2-min');

SELECT cron.schedule(
  'easyorders-sync-every-2-min',
  '*/2 * * * *',
  $$
  SELECT net.http_post(
    url := 'https://jxmtnspicjpbvphlgzlz.supabase.co/functions/v1/easyorders-sync',
    headers := '{"Content-Type":"application/json","apikey":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4bXRuc3BpY2pwYnZwaGxnemx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2MTkyMDksImV4cCI6MjA5NTE5NTIwOX0._g2XRJRDnWnX3c9SnX1CVW2GnBVlEAN_BC9LnzTW8L8","Authorization":"Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4bXRuc3BpY2pwYnZwaGxnemx6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk2MTkyMDksImV4cCI6MjA5NTE5NTIwOX0._g2XRJRDnWnX3c9SnX1CVW2GnBVlEAN_BC9LnzTW8L8"}'::jsonb,
    body := '{}'::jsonb
  );
  $$
);
