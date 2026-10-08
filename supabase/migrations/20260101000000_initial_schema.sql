-- ResQ database schema, rebuilt from the queries in lib/ (the original project's
-- schema was never committed). Applied automatically by `supabase start` /
-- `supabase db reset`.
--
-- Row level security is enabled everywhere, but the policies are deliberately
-- simple (signed-in users can read and write) so every screen works for demos.
-- Tighten them before using this with real users.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------------
-- Users
-- ---------------------------------------------------------------------------

create table public.users (
  id          uuid primary key references auth.users (id) on delete cascade,
  email       text,
  full_name   text,
  phone       text,
  gender      text,
  role        text not null default 'volunteer',   -- volunteer | shelter | clinic
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- Every sign-up gets a public.users row; the app only ever UPDATEs it.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.users (id, email, full_name, phone, role)
  values (
    new.id,
    new.email,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone',
    coalesce(new.raw_user_meta_data ->> 'role', 'volunteer')
  )
  on conflict (id) do nothing;
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

create table public.user_verifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.users (id) on delete cascade,
  id_number   text,
  doc_type    text,
  status      text not null default 'pending',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.media_files (
  id           uuid primary key default gen_random_uuid(),
  owner_type   text,
  owner_id     uuid,
  kind         text,
  bucket       text not null,
  path         text not null,
  mime_type    text,
  uploaded_by  uuid references public.users (id) on delete set null,
  created_at   timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Shelters and clinics
-- ---------------------------------------------------------------------------

create table public.shelters (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references public.users (id) on delete cascade,
  name            text not null,
  phone           text,
  address         text,
  city            text,
  description     text,
  working_hours   text,
  license_number  text,
  status          text not null default 'pending',   -- pending | approved | rejected
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.clinics (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid references public.users (id) on delete cascade,
  name            text not null,
  phone           text,
  address         text,
  city            text,
  description     text,
  working_hours   text,
  license_number  text,
  status          text not null default 'pending',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

create table public.shelter_verifications (
  id          uuid primary key default gen_random_uuid(),
  shelter_id  uuid not null references public.shelters (id) on delete cascade,
  status      text not null default 'pending',
  notes       text,
  created_at  timestamptz not null default now()
);

create table public.clinic_verifications (
  id          uuid primary key default gen_random_uuid(),
  clinic_id   uuid not null references public.clinics (id) on delete cascade,
  status      text not null default 'pending',
  notes       text,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Rescue cases
-- ---------------------------------------------------------------------------

create table public.cases (
  id                uuid primary key default gen_random_uuid(),
  animal_type       text,
  severity          text,                               -- low | normal | moderate | high | emergency
  description       text,
  location_lat      double precision,
  location_lng      double precision,
  location_text     text,
  reported_by       uuid references public.users (id) on delete set null,
  status            text not null default 'new',        -- new | assigned | in_progress | resolved
  claimed_by_id     uuid,                               -- the claiming shelter account's user id
  claimed_by_type   text,
  claimed_at        timestamptz,
  assigned_to_id    uuid,                               -- clinics.id of the accepting clinic
  assigned_to_type  text,
  close_reason      text,
  closed_at         timestamptz,
  closed_by         uuid,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

create table public.case_photos (
  id          uuid primary key default gen_random_uuid(),
  case_id     uuid not null references public.cases (id) on delete cascade,
  bucket      text not null,
  path        text not null,
  created_at  timestamptz not null default now()
);

create table public.donations (
  id              uuid primary key default gen_random_uuid(),
  donor_user_id   uuid references public.users (id) on delete set null,
  case_id         uuid references public.cases (id) on delete set null,
  amount          numeric(12, 2) not null,
  currency        text not null default 'EGP',
  status          text not null default 'completed',
  payment_method  text,
  transaction_id  text,
  notes           text,
  created_at      timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Adoption
-- ---------------------------------------------------------------------------

create table public.animals (
  id                   uuid primary key default gen_random_uuid(),
  owner_user_id        uuid references public.users (id) on delete cascade,
  shelter_id           uuid references public.shelters (id) on delete cascade,
  name                 text not null,
  species              text,
  breed                text,
  age                  text,
  gender               text,
  size                 text,
  color                text,
  vaccinated           boolean not null default false,
  is_neutered          boolean not null default false,
  health_condition     text,
  special_needs        text,
  friendly_people      boolean not null default false,
  friendly_kids        boolean not null default false,
  friendly_animals     boolean not null default false,
  house_trained        boolean not null default false,
  energy_level         text,
  living_preference    text,
  adoption_fee         numeric(12, 2) not null default 0,
  home_visit_required  boolean not null default false,
  contract_required    boolean not null default false,
  city                 text,
  area                 text,
  preferred_contact    text,
  contact_phone        text,
  status               text not null default 'available',  -- available | adopted | in_treatment | foster
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now()
);

-- The add-animal screen only sends owner_user_id; link the owner's shelter.
create function public.set_animal_shelter() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.shelter_id is null and new.owner_user_id is not null then
    select id into new.shelter_id from public.shelters where user_id = new.owner_user_id limit 1;
  end if;
  return new;
end $$;

create trigger animals_set_shelter
  before insert on public.animals
  for each row execute function public.set_animal_shelter();

create table public.animal_photos (
  id          uuid primary key default gen_random_uuid(),
  animal_id   uuid not null references public.animals (id) on delete cascade,
  bucket      text not null,
  path        text not null,
  is_cover    boolean not null default false,
  created_at  timestamptz not null default now()
);

create table public.adoption_requests (
  id                 uuid primary key default gen_random_uuid(),
  animal_id          uuid not null references public.animals (id) on delete cascade,
  -- constraint name is referenced by the app: users!adoption_requests_applicant_user_id_fkey
  applicant_user_id  uuid not null
    constraint adoption_requests_applicant_user_id_fkey references public.users (id) on delete cascade,
  status             text not null default 'pending',  -- pending | approved | rejected | interview_scheduled
  decision_reason    text,
  decided_by         uuid references public.users (id) on delete set null,
  decided_at         timestamptz,
  created_at         timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Lost and found
-- ---------------------------------------------------------------------------

create table public.lost_found_reports (
  id             uuid primary key default gen_random_uuid(),
  type           text not null,          -- lost | found
  animal_type    text,
  description    text,
  location_text  text,
  location_lat   double precision,
  location_lng   double precision,
  created_by     uuid references public.users (id) on delete set null,
  status         text not null default 'open',
  created_at     timestamptz not null default now()
);

create table public.lost_found_photos (
  id          uuid primary key default gen_random_uuid(),
  report_id   uuid not null references public.lost_found_reports (id) on delete cascade,
  bucket      text not null,
  path        text not null,
  created_at  timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Chat, support and notifications
-- ---------------------------------------------------------------------------

create table public.conversations (
  id          uuid primary key default gen_random_uuid(),
  type        text not null default 'direct',   -- direct | support
  created_at  timestamptz not null default now()
);

create table public.conversation_participants (
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  user_id          uuid not null references public.users (id) on delete cascade,
  joined_at        timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table public.messages (
  id               uuid primary key default gen_random_uuid(),
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  sender_user_id   uuid references public.users (id) on delete set null,
  body             text not null,
  created_at       timestamptz not null default now()
);

create index messages_conversation_created_idx on public.messages (conversation_id, created_at);

create table public.support_tickets (
  id               uuid primary key default gen_random_uuid(),
  user_id          uuid not null references public.users (id) on delete cascade,
  conversation_id  uuid not null references public.conversations (id) on delete cascade,
  subject          text,
  status           text not null default 'open',   -- open | in_progress | resolved | closed
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table public.ticket_ratings (
  id          uuid primary key default gen_random_uuid(),
  ticket_id   uuid not null references public.support_tickets (id) on delete cascade,
  user_id     uuid references public.users (id) on delete set null,
  rating      int not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz not null default now()
);

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  body        text,
  created_at  timestamptz not null default now()
);

create table public.notification_deliveries (
  id               uuid primary key default gen_random_uuid(),
  notification_id  uuid not null references public.notifications (id) on delete cascade,
  user_id          uuid not null references public.users (id) on delete cascade,
  read_at          timestamptz,
  created_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Row level security (demo-grade: any signed-in user can read and write)
-- ---------------------------------------------------------------------------

do $$
declare
  t text;
begin
  foreach t in array array[
    'users', 'user_verifications', 'media_files', 'shelters', 'clinics',
    'shelter_verifications', 'clinic_verifications', 'cases', 'case_photos',
    'donations', 'animals', 'animal_photos', 'adoption_requests',
    'lost_found_reports', 'lost_found_photos', 'conversations',
    'conversation_participants', 'messages', 'support_tickets',
    'ticket_ratings', 'notifications', 'notification_deliveries'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "signed-in users full access" on public.%I for all to authenticated using (true) with check (true)', t);
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Realtime (screens using .stream())
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table
  public.cases, public.messages, public.animals, public.support_tickets;

-- ---------------------------------------------------------------------------
-- Storage buckets
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public) values
  ('case_photos',         'case_photos',         true),
  ('animal_photos',       'animal_photos',       true),
  ('lost_found_photos',   'lost_found_photos',   true),
  ('support_attachments', 'support_attachments', true),
  ('verification_docs',   'verification_docs',   false)
on conflict (id) do nothing;

create policy "signed-in users manage app files" on storage.objects
  for all to authenticated
  using (bucket_id in ('case_photos', 'animal_photos', 'lost_found_photos', 'support_attachments', 'verification_docs'))
  with check (bucket_id in ('case_photos', 'animal_photos', 'lost_found_photos', 'support_attachments', 'verification_docs'));
