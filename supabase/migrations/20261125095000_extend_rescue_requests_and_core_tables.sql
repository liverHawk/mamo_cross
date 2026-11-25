-- 1. private スキーマ（SECURITY DEFINER ヘルパー用）
create schema if not exists private;

-- 2. rescue_requests 拡張
alter table public.rescue_requests
  add column if not exists user_id uuid references auth.users(id) on delete set null,
  add column if not exists latitude double precision,
  add column if not exists longitude double precision,
  add column if not exists lat_percent double precision not null default 50.0,
  add column if not exists top_percent double precision not null default 50.0,
  add column if not exists assigned_agency text,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_rescue_requests_created_at_id
  on public.rescue_requests (created_at desc, id asc);

create index if not exists idx_rescue_requests_user_id
  on public.rescue_requests (user_id);

-- 3. profiles テーブル
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'あなた',
  birth_date text not null default '',
  blood_type text not null default '',
  gender text not null default '',
  postal_code text not null default '',
  prefecture text not null default '',
  address_detail text not null default '',
  considerations text[] not null default '{}',
  other_consideration text not null default '',
  safety_status text not null default 'safe'
    check (safety_status in ('safe', 'damaged', 'rescueNeeded')),
  location_note text not null default '〇〇地区付近',
  safety_updated_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own" on public.profiles
  for select to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "profiles_insert_own" on public.profiles;
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated
  with check ((select auth.uid()) = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- 4. family_groups & family_members テーブル
create table if not exists public.family_groups (
  id uuid primary key default gen_random_uuid(),
  name text not null default 'マイ家族グループ',
  invite_code text unique not null,
  created_by uuid references auth.users(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now()
);

create table if not exists public.family_members (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.family_groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  display_name text not null default '家族',
  avatar text not null default '🙂',
  role text not null default 'member',
  safety_status text not null default 'safe'
    check (safety_status in ('safe', 'damaged', 'rescueNeeded')),
  location_note text not null default '',
  safety_updated_at timestamptz not null default now(),
  joined_at timestamptz not null default now(),
  unique (group_id, user_id)
);

create index if not exists idx_family_members_group_id
  on public.family_members (group_id);

create index if not exists idx_family_members_user_id
  on public.family_members (user_id);

-- 無限再帰を防ぐための所属グループID取得ヘルパー（privateスキーマ）
create or replace function private.user_family_group_ids()
returns uuid[]
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(array_agg(group_id), '{}'::uuid[])
  from public.family_members
  where user_id = (select auth.uid());
$$;

alter table public.family_groups enable row level security;
alter table public.family_members enable row level security;

drop policy if exists "family_groups_select_member_or_creator" on public.family_groups;
create policy "family_groups_select_member_or_creator" on public.family_groups
  for select to authenticated
  using (
    created_by = (select auth.uid())
    or id = any(private.user_family_group_ids())
  );

drop policy if exists "family_groups_insert_authenticated" on public.family_groups;
create policy "family_groups_insert_authenticated" on public.family_groups
  for insert to authenticated
  with check (created_by = (select auth.uid()));

drop policy if exists "family_members_select_same_group" on public.family_members;
create policy "family_members_select_same_group" on public.family_members
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or group_id = any(private.user_family_group_ids())
  );

drop policy if exists "family_members_insert_self" on public.family_members;
create policy "family_members_insert_self" on public.family_members
  for insert to authenticated
  with check (user_id = (select auth.uid()));

drop policy if exists "family_members_update_self" on public.family_members;
create policy "family_members_update_self" on public.family_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));

drop policy if exists "family_members_delete_self" on public.family_members;
create policy "family_members_delete_self" on public.family_members
  for delete to authenticated
  using (user_id = (select auth.uid()));

-- 招待コードで家族グループに参加する RPC（auth.uid() 必須チェック）
create or replace function public.join_family_group_by_code(
  p_invite_code text,
  p_display_name text default 'あなた',
  p_avatar text default '🙂'
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_group_id uuid;
  v_status text := 'safe';
  v_location text := '〇〇地区付近';
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select id into v_group_id
  from public.family_groups
  where upper(invite_code) = upper(trim(p_invite_code))
  limit 1;

  if v_group_id is null then
    raise exception 'Family group not found for invite code';
  end if;

  select coalesce(safety_status, 'safe'), coalesce(location_note, '〇〇地区付近')
  into v_status, v_location
  from public.profiles
  where id = v_uid;

  insert into public.family_members (
    group_id, user_id, display_name, avatar, safety_status, location_note, safety_updated_at
  )
  values (
    v_group_id,
    v_uid,
    coalesce(nullif(trim(p_display_name), ''), 'あなた'),
    coalesce(nullif(trim(p_avatar), ''), '🙂'),
    coalesce(v_status, 'safe'),
    coalesce(v_location, '〇〇地区付近'),
    now()
  )
  on conflict (group_id, user_id) do update
    set display_name = excluded.display_name,
        avatar = excluded.avatar,
        safety_status = excluded.safety_status,
        location_note = excluded.location_note,
        safety_updated_at = now();

  return v_group_id;
end;
$$;

-- profiles 更新時に family_members の安否・表示名を同期するトリガー
create or replace function private.sync_profile_to_family_members()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.family_members
  set display_name = new.display_name,
      safety_status = new.safety_status,
      location_note = new.location_note,
      safety_updated_at = new.safety_updated_at
  where user_id = new.id;
  return new;
end;
$$;

drop trigger if exists trg_sync_profile_to_family_members on public.profiles;
create trigger trg_sync_profile_to_family_members
  after insert or update of display_name, safety_status, location_note, safety_updated_at
  on public.profiles
  for each row
  execute function private.sync_profile_to_family_members();

-- 5. messages テーブル（自治体お知らせ・家族連絡）
create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  kind text not null check (kind in ('municipality_notice', 'family_thread')),
  group_id uuid references public.family_groups(id) on delete cascade,
  sender_id uuid references auth.users(id) on delete set null default auth.uid(),
  sender_name text not null,
  avatar text not null default '🙂',
  body text not null,
  is_important boolean not null default false,
  created_at timestamptz not null default now()
);

create index if not exists idx_messages_kind_created_at
  on public.messages (kind, created_at asc);

create index if not exists idx_messages_group_id_created_at
  on public.messages (group_id, created_at asc);

alter table public.messages enable row level security;

drop policy if exists "messages_select_public_notices" on public.messages;
create policy "messages_select_public_notices" on public.messages
  for select to anon, authenticated
  using (kind = 'municipality_notice');

drop policy if exists "messages_select_family_thread" on public.messages;
create policy "messages_select_family_thread" on public.messages
  for select to authenticated
  using (
    kind = 'family_thread'
    and group_id = any(private.user_family_group_ids())
  );

drop policy if exists "messages_insert_family_thread" on public.messages;
create policy "messages_insert_family_thread" on public.messages
  for insert to authenticated
  with check (
    kind = 'family_thread'
    and sender_id = (select auth.uid())
    and group_id = any(private.user_family_group_ids())
  );

drop policy if exists "messages_insert_municipality_notice" on public.messages;
create policy "messages_insert_municipality_notice" on public.messages
  for insert to anon, authenticated
  with check (kind = 'municipality_notice');

-- 6. shelters テーブル
create table if not exists public.shelters (
  id text primary key,
  name text not null,
  distance_text text not null default '',
  status_text text not null default '',
  is_open boolean not null default true,
  address text not null default '',
  capacity integer not null default 100,
  occupied integer not null default 0,
  facilities text[] not null default '{}',
  x_percent double precision not null default 0.5,
  y_percent double precision not null default 0.5,
  latitude double precision,
  longitude double precision,
  updated_at timestamptz not null default now()
);

alter table public.shelters enable row level security;

drop policy if exists "shelters_select_all" on public.shelters;
create policy "shelters_select_all" on public.shelters
  for select to anon, authenticated
  using (true);

drop policy if exists "shelters_update_all" on public.shelters;
create policy "shelters_update_all" on public.shelters
  for update to anon, authenticated
  using (true)
  with check (occupied >= 0 and capacity >= 0);

-- 7. hazard_spots テーブル
create table if not exists public.hazard_spots (
  id text primary key,
  title text not null,
  description text not null default '',
  x_percent double precision not null default 0.5,
  y_percent double precision not null default 0.5,
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.hazard_spots enable row level security;

drop policy if exists "hazard_spots_select_all" on public.hazard_spots;
create policy "hazard_spots_select_all" on public.hazard_spots
  for select to anon, authenticated
  using (true);

-- 8. Realtime Publication 登録
do $$
declare
  t text;
begin
  foreach t in array array['rescue_requests', 'profiles', 'family_members', 'messages', 'shelters', 'hazard_spots']
  loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;

-- 9. 初期シードデータ（避難所・危険箇所・自治体お知らせ）
insert into public.shelters (
  id, name, distance_text, status_text, is_open, address, capacity, occupied, facilities, x_percent, y_percent
) values
  ('shelter_1', '〇〇地区 〇〇小学校', '150m先', '避難所開設', true, '〇〇地区1-2-3', 300, 128, array['給水', '非常電源', '医療救護', 'バリアフリー'], 0.62, 0.36),
  ('shelter_2', '〇〇公民館（福祉避難所）', '420m先', '避難所開設（要配慮者優先）', true, '〇〇地区2-8-10', 120, 54, array['福祉対応', '授乳室', '車椅子対応', '非常電源'], 0.28, 0.58),
  ('shelter_3', '中央防災公園（一時避難場所）', '650m先', '広域避難場所・給水車待機', true, '〇〇地区中央4-1', 800, 210, array['給水車', '仮設トイレ', 'ヘリポート'], 0.78, 0.72)
on conflict (id) do nothing;

insert into public.hazard_spots (
  id, title, description, x_percent, y_percent, is_active
) values
  ('hazard_1', 'ブロック塀倒壊のおそれ', '〇〇小学校西側の通学路沿い・迂回推奨', 0.44, 0.28, true),
  ('hazard_2', '一部道路冠水・通行止め', '〇〇川沿いアンダーパス通行不可', 0.72, 0.55, true)
on conflict (id) do nothing;

insert into public.messages (
  id, kind, sender_name, avatar, body, is_important, created_at
) values
  ('00000000-0000-0000-0000-000000000001', 'municipality_notice', '〇〇市 災害対策本部', '🏛️', '【緊急】〇〇地区で震度5強を観測しました。〇〇地区 〇〇小学校ほか2箇所の避難所を開設しています。', true, now() - interval '20 minutes'),
  ('00000000-0000-0000-0000-000000000002', 'municipality_notice', '〇〇市 防災無線', '📢', '〇〇小学校にて給水および非常電源の提供を開始しました。余震にご注意ください。', false, now() - interval '10 minutes')
on conflict (id) do nothing;