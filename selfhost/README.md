# Self-hosting ResQ's backend (Supabase on your own server)

The cloud project `dgwrsfjpxuvgqrbhhjro` is paused past the restore window. This guide moves
its data (database, user logins, uploaded files) to a self-hosted Supabase that has no
project limit and never pauses. The Flutter app keeps using `supabase_flutter`; only the
URL and anon key change.

## 0. Save the data out of the paused project (do this first)

In the Supabase dashboard, open the paused project and download:

1. **Database backup**: `db_cluster-….backup.gz`. It contains every table, RLS policy, function,
   trigger and the `auth.users` rows (emails and password hashes, so users keep their passwords).
2. **Storage objects**: every bucket (`verification_docs`, `support_attachments`, the photo
   buckets, …). Unzip so you have one folder per bucket, e.g. `storage-export/verification_docs/...`.
3. **Edge function source**: the app calls two functions, but only `payment-intent` is in this
   repo. **`support-open-thread` (used by `support_chat_screen.dart`) is missing.** Check your
   computer for it. If it's gone, it has to be rewritten: it takes `{subject}` and returns
   `{conversation_id, ticket_id}`.

If the download buttons are missing, ask Supabase support (Dashboard → Support) for the
backup and storage export of project `dgwrsfjpxuvgqrbhhjro`.

## 1. Get a server

You need a Linux VPS with **at least 4 GB RAM** (8 GB is more comfortable) and Docker.

- **Free:** Oracle Cloud "Always Free" Ampere A1 (up to 4 CPU / 24 GB RAM, ARM64; the
  Supabase images support ARM). Open ports 80 and 443 both in the VCN security list *and* in
  the instance firewall (`sudo iptables -I INPUT -p tcp -m multiport --dports 80,443 -j ACCEPT`).
- **Cheap and simple:** Hetzner CAX21 / CX32, DigitalOcean, Contabo.

Install Docker:

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER   # log out and back in
```

## 2. Install Supabase

```bash
git clone --depth 1 https://github.com/supabase/supabase
mkdir -p ~/supabase && cp -r supabase/docker ~/supabase/ && rm -rf supabase
cd ~/supabase/docker
cp .env.example .env
```

Generate secrets with the script in this folder and paste them over the matching lines in `.env`:

```bash
python3 ~/ResQ/selfhost/generate-keys.py > ~/keys.env
cat ~/keys.env     # copy each value into ~/supabase/docker/.env
```

Also set these in `.env` (use your domain from step 3):

```
SITE_URL=https://api.example.com
API_EXTERNAL_URL=https://api.example.com
SUPABASE_PUBLIC_URL=https://api.example.com
ENABLE_EMAIL_AUTOCONFIRM=true      # the cloud project didn't require email confirmation
```

For **password-reset emails** (`resetPasswordForEmail` in the profile screen), fill the
`SMTP_*` variables with a free SMTP provider (Brevo, Resend, Mailjet…). Without SMTP,
everything works except emails.

If `.env.example` has variables this guide doesn't mention, keep their defaults. Supabase
adds settings over time.

Start it:

```bash
docker compose pull
docker compose up -d
docker compose ps        # wait until everything is "healthy"
```

## 3. HTTPS domain

Phones refuse plain `http` by default, so put the API behind HTTPS.

- No domain? Use `<your-ip-with-dashes>.sslip.io` (e.g. `129-151-10-20.sslip.io`). It works
  with Let's Encrypt for free. Or create a free DuckDNS subdomain.

```bash
sudo apt install -y caddy
sudo cp ~/ResQ/selfhost/Caddyfile /etc/caddy/Caddyfile
sudo nano /etc/caddy/Caddyfile   # replace api.example.com with your domain
sudo systemctl reload caddy
```

Studio (the dashboard) is now at `https://<domain>` with `DASHBOARD_USERNAME` / `DASHBOARD_PASSWORD`.

## 4. Restore the database

Copy the backup to the server (`scp db_cluster-*.backup.gz ubuntu@SERVER:~`), then:

```bash
cd ~/ResQ/selfhost
./restore-db.sh ~/db_cluster-XX.backup.gz
```

The script loads the dump into the `supabase-db` container. It skips the cloud's role
passwords so the self-hosted services can still log in. At the end it prints the
non-trivial errors, row counts, and which tables are enabled for realtime.

- Lots of `already exists` errors are normal. The fresh database already has Supabase's own
  schemas.
- Check `auth.users`, `public.users` and `public.cases` counts look right.
- The app uses realtime (`.stream()`) on cases, messages, support tickets, etc. If a table is
  missing from the realtime list, add it in Studio (Database → Publications) or run
  `ALTER PUBLICATION supabase_realtime ADD TABLE public.<table>;`

If some of your tables still store **full image URLs** (with the old `supabase.co` host),
rewrite them:

```bash
docker exec -i supabase-db psql -U supabase_admin -d postgres \
  -v old='https://dgwrsfjpxuvgqrbhhjro.supabase.co' -v new='https://api.example.com' \
  < rewrite-urls.sql
```

## 5. Restore the uploaded files

```bash
scp -r storage-export ubuntu@SERVER:~
python3 ~/ResQ/selfhost/upload-storage.py ~/storage-export https://api.example.com <SERVICE_ROLE_KEY>
```

It uploads every file to the same bucket and path, so references in the database keep
working. It is safe to re-run. The app uses `getPublicUrl()`, so any bucket that was
**public** in the cloud must still be public. The restored DB keeps that setting. Check it
in Studio → Storage.

## 6. Edge functions

```bash
cp -r ~/ResQ/supabase/functions/payment-intent ~/supabase/docker/volumes/functions/
# also copy support-open-thread here once you have/rewrite it
```

`payment-intent` needs the Stripe secret. Add `STRIPE_SECRET_KEY=sk_...` to `.env`, then in
`docker-compose.yml` under the `functions` service's `environment:` add:

```yaml
      STRIPE_SECRET_KEY: ${STRIPE_SECRET_KEY}
```

Restart with `docker compose up -d functions`. Functions are then served at
`https://<domain>/functions/v1/<name>`, the same path the app already uses.

## 7. Point the app at the new server

The URL and key now live in one place, `lib/config/supabase_config.dart`. Either change the
defaults there, or pass them at build time:

```bash
flutter run   --dart-define=SUPABASE_URL=https://api.example.com --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>
flutter build apk --dart-define=SUPABASE_URL=https://api.example.com --dart-define=SUPABASE_ANON_KEY=<ANON_KEY>
```

Users have to sign in again (new JWT secret), but their email and password still work.

## 8. Backups (don't skip)

Self-hosting means you are the backup system now:

```bash
crontab -e
# add:
30 3 * * * /home/ubuntu/ResQ/selfhost/backup.sh >> /home/ubuntu/backup.log 2>&1
```

`backup.sh` keeps 14 days of database dumps and storage archives in `~/backups`. Also copy
them **off the server** (e.g. `rclone copy ~/backups gdrive:resq-backups`, also in cron).
Free Oracle instances can be reclaimed if your account is idle.

Restoring one of these backups onto a new server: install Supabase as in step 2, then
`gunzip -c db-XXX.sql.gz | docker exec -i supabase-db psql -U supabase_admin -d postgres`
and `tar -xzf storage-XXX.tar.gz -C ~/supabase/docker/volumes`.

## Also recommended

Save the schema in git so the structure can never be lost again. On the server:

```bash
docker exec supabase-db pg_dump -U supabase_admin -d postgres --schema-only --schema=public \
  > ~/ResQ/supabase/schema.sql
```

Then commit `supabase/schema.sql`. Re-run it whenever you change tables or policies.
