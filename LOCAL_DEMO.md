# Run ResQ locally (no Supabase cloud project needed)

The whole backend (database, logins, photo storage, realtime chat, edge functions) runs on
your own computer with Docker. The database comes from
`supabase/migrations/20260101000000_initial_schema.sql`, and `supabase/seed.sql` adds demo
shelters, clinics, rescue cases, adoptable animals and lost & found posts.

## One-time setup

1. Install **Docker Desktop** and start it.
2. Install the **Supabase CLI**. Or skip installing it and put `npx` in front of every
   `supabase` command below (`npx supabase start`); that needs Node.js.

## Every time

```bash
# in the ResQ folder
supabase start
```

The first run downloads the images (a few minutes). When it finishes it prints:

- `API URL`: http://127.0.0.1:54321
- `anon key` (or `Publishable key` on newer CLIs): copy it
- `Studio URL`: http://127.0.0.1:54323, a dashboard to view and edit the data

Run the app against it:

```bash
# Android emulator (10.0.2.2 = your computer, seen from the emulator)
flutter run --dart-define=SUPABASE_URL=http://10.0.2.2:54321 --dart-define=SUPABASE_ANON_KEY=<anon key>

# Chrome
flutter run -d chrome --dart-define=SUPABASE_URL=http://127.0.0.1:54321 --dart-define=SUPABASE_ANON_KEY=<anon key>

# Real phone on the same Wi-Fi: use your computer's LAN IP, e.g. http://192.168.1.20:54321
```

## Accounts

Register inside the app. Email confirmation is off, so you're logged in straight away.

- **Volunteer:** the normal register screen.
- **Shelter / clinic:** their registration screens. New shelters and clinics start as
  `pending`, so they don't appear in lists until approved. Approve them in Studio
  (Table Editor → `shelters` / `clinics` → set `status` to `approved`), or in the SQL editor:

  ```sql
  update shelters set status = 'approved';
  update clinics  set status = 'approved';
  ```

## Notes

- **Data survives** `supabase stop` / `supabase start`. `supabase db reset` wipes everything
  and reloads the demo data.
- **Support chat** uses the `support-open-thread` edge function, which `supabase start`
  serves automatically. If the chat says it can't connect, run `supabase functions serve`
  in a second terminal.
- **Donations** need a Stripe test key. Put `STRIPE_SECRET_KEY=sk_test_...` in
  `supabase/functions/.env` and run `supabase functions serve --env-file supabase/functions/.env`.
- **Security:** the database policies let any signed-in user read and write everything.
  That's fine for a local demo; tighten them before going live with real users.
