-- ReLoop online marketplace schema (Supabase / PostgreSQL)
-- Run this in Supabase Dashboard -> SQL Editor.
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text unique not null check (username ~ '^[A-Za-z0-9_]{3,24}$'),
  display_name text not null default '',
  avatar_url text,
  created_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  seller_id uuid not null references public.profiles(id) on delete cascade,
  title text not null check (char_length(title) between 3 and 120),
  description text not null default '',
  price numeric(12,2) not null check (price >= 0),
  category text not null default 'other',
  condition text not null default 'used',
  image_urls text[] not null default '{}',
  model_url text,
  status text not null default 'active' check (status in ('active','reserved','sold','hidden')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists listings_status_created_idx on public.listings(status, created_at desc);
create index if not exists listings_seller_idx on public.listings(seller_id);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid references public.listings(id) on delete set null,
  buyer_id uuid not null references public.profiles(id) on delete cascade,
  seller_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz not null default now(),
  unique (listing_id, buyer_id, seller_id),
  check (buyer_id <> seller_id)
);
create index if not exists conversations_buyer_idx on public.conversations(buyer_id, last_message_at desc);
create index if not exists conversations_seller_idx on public.conversations(seller_id, last_message_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 4000),
  created_at timestamptz not null default now(),
  read_at timestamptz
);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at);

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

drop policy if exists "Profiles readable" on public.profiles;
create policy "Profiles readable" on public.profiles for select using (true);
drop policy if exists "Users create own profile" on public.profiles;
create policy "Users create own profile" on public.profiles for insert to authenticated with check (id = auth.uid());
drop policy if exists "Users update own profile" on public.profiles;
create policy "Users update own profile" on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "Active listings readable" on public.listings;
create policy "Active listings readable" on public.listings for select using (status = 'active' or seller_id = auth.uid());
drop policy if exists "Signed-in users create own listings" on public.listings;
create policy "Signed-in users create own listings" on public.listings for insert to authenticated with check (seller_id = auth.uid());
drop policy if exists "Sellers update own listings" on public.listings;
create policy "Sellers update own listings" on public.listings for update to authenticated using (seller_id = auth.uid()) with check (seller_id = auth.uid());
drop policy if exists "Sellers delete own listings" on public.listings;
create policy "Sellers delete own listings" on public.listings for delete to authenticated using (seller_id = auth.uid());

drop policy if exists "Conversation members can read" on public.conversations;
create policy "Conversation members can read" on public.conversations for select to authenticated using (buyer_id = auth.uid() or seller_id = auth.uid());
drop policy if exists "Buyer starts conversation" on public.conversations;
create policy "Buyer starts conversation" on public.conversations for insert to authenticated with check (buyer_id = auth.uid() and buyer_id <> seller_id);
drop policy if exists "Members update conversation" on public.conversations;
create policy "Members update conversation" on public.conversations for update to authenticated using (buyer_id = auth.uid() or seller_id = auth.uid()) with check (buyer_id = auth.uid() or seller_id = auth.uid());

drop policy if exists "Conversation members read messages" on public.messages;
create policy "Conversation members read messages" on public.messages for select to authenticated using (
  exists (select 1 from public.conversations c where c.id = conversation_id and (c.buyer_id = auth.uid() or c.seller_id = auth.uid()))
);
drop policy if exists "Members send messages as themselves" on public.messages;
create policy "Members send messages as themselves" on public.messages for insert to authenticated with check (
  sender_id = auth.uid() and exists (
    select 1 from public.conversations c where c.id = conversation_id and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
  )
);

-- Public product images can use a public bucket named listing-images.
-- Never put the Supabase service_role key in the website or APK.
