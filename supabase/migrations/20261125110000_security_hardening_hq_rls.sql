-- Security hardening: HQ role-based access to rescue_requests, least privilege,
-- realtime exposure reduction, input constraints, invite-code brute-force defence.

-- 1. rescue_requests: 一般ユーザーは自分の要請のみ。全件閲覧・更新は app_metadata.role = 'hq_admin' のみ
--    （user_metadata はユーザー改ざん可能なため使用しない）
drop policy if exists "exhibition_select_rescue_requests" on public.rescue_requests;
drop policy if exists "exhibition_insert_rescue_requests" on public.rescue_requests;
drop policy if exists "exhibition_update_rescue_requests" on public.rescue_requests;
drop policy if exists "rescue_requests_insert" on public.rescue_requests;
drop policy if exists "rescue_requests_select" on public.rescue_requests;
drop policy if exists "rescue_requests_update_hq" on public.rescue_requests;

create policy "rescue_requests_insert" on public.rescue_requests
  for insert to anon, authenticated
  with check (
    status = '未対応'
    and assigned_agency is null
    and (user_id is null or user_id = (select auth.uid()))
  );

create policy "rescue_requests_select" on public.rescue_requests
  for select to authenticated
  using (
    ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'hq_admin'
    or user_id = (select auth.uid())
  );

create policy "rescue_requests_update_hq" on public.rescue_requests
  for update to authenticated
  using (((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'hq_admin')
  with check (
    ((select auth.jwt()) -> 'app_metadata' ->> 'role') = 'hq_admin'
    and status in ('未対応', '対応中', '対応済み')
  );

-- サーバー時刻の強制（クライアントによる created_at 偽装防止）
create or replace function private.rescue_requests_set_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
  end if;
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function private.rescue_requests_set_timestamps() from public, anon, authenticated;

drop trigger if exists trg_rescue_requests_timestamps on public.rescue_requests;
create trigger trg_rescue_requests_timestamps
  before insert or update on public.rescue_requests
  for each row execute function private.rescue_requests_set_timestamps();

-- 2. 最小権限化（TRUNCATE / TRIGGER / REFERENCES / DELETE の剥奪）
revoke truncate, trigger, references, delete on all tables in schema public from anon, authenticated;
grant delete on public.family_members to authenticated;

revoke all on public.rescue_requests from anon, authenticated;
grant insert on public.rescue_requests to anon;
grant select, insert on public.rescue_requests to authenticated;
grant update (status, assigned_agency, updated_at) on public.rescue_requests to authenticated;

revoke all on public.profiles, public.family_groups, public.family_members from anon;
revoke insert, update on public.messages from anon;

-- 3. Realtime 露出の最小化
alter table public.rescue_requests replica identity default;
do $$
declare t text;
begin
  foreach t in array array['profiles', 'hazard_spots']
  loop
    if exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime drop table public.%I', t);
    end if;
  end loop;
end $$;

-- 4. 入力長・数値範囲 CHECK 制約（既存行は NOT VALID で許容し、新規/更新行を強制）
alter table public.rescue_requests
  add constraint rescue_requests_len_chk check (
    char_length(coalesce(request_id, '')) <= 64
    and char_length(coalesce(request_type, '')) <= 32
    and char_length(coalesce(user_name, '')) <= 100
    and char_length(coalesce(requester_name, '')) <= 100
    and char_length(coalesce(detail, '')) <= 1000
    and char_length(coalesce(rescue_details, '')) <= 1000
    and char_length(coalesce(consideration, '')) <= 500
    and char_length(coalesce(considerations, '')) <= 500
    and char_length(coalesce(health_condition, '')) <= 500
    and char_length(coalesce(location, '')) <= 300
    and char_length(coalesce(location_text, '')) <= 300
    and char_length(coalesce(distance, '')) <= 64
    and char_length(coalesce(distance_text, '')) <= 64
  ) not valid,
  add constraint rescue_requests_geo_chk check (
    (latitude is null or latitude between -90 and 90)
    and (longitude is null or longitude between -180 and 180)
    and lat_percent between 0 and 100
    and top_percent between 0 and 100
  ) not valid;

alter table public.profiles
  add constraint profiles_len_chk check (
    char_length(display_name) <= 100
    and char_length(birth_date) <= 32
    and char_length(blood_type) <= 16
    and char_length(gender) <= 16
    and char_length(postal_code) <= 16
    and char_length(prefecture) <= 16
    and char_length(address_detail) <= 300
    and cardinality(considerations) <= 20
    and char_length(other_consideration) <= 500
    and char_length(location_note) <= 200
  ) not valid;

alter table public.messages
  add constraint messages_len_chk check (
    char_length(sender_name) <= 100
    and char_length(avatar) <= 16
    and char_length(body) <= 1000
  ) not valid,
  add constraint messages_kind_group_chk check (
    (kind = 'municipality_notice' and group_id is null)
    or (kind = 'family_thread' and group_id is not null)
  ) not valid;

alter table public.family_groups
  add constraint family_groups_fmt_chk check (
    char_length(name) <= 100
    and invite_code ~ '^[A-Z0-9]{6,12}$'
  ) not valid;

alter table public.family_members
  add constraint family_members_len_chk check (
    char_length(display_name) <= 100
    and char_length(avatar) <= 16
    and char_length(location_note) <= 200
  ) not valid;

-- 5. 招待コード総当たり対策（1ユーザー1分5回・グループ上限10名・入力長検証）
create table if not exists private.join_attempts (
  user_id uuid not null,
  attempted_at timestamptz not null default now()
);
create index if not exists idx_join_attempts_user_time
  on private.join_attempts (user_id, attempted_at desc);
alter table private.join_attempts enable row level security;
revoke all on private.join_attempts from public, anon, authenticated;

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
  v_code text := upper(trim(coalesce(p_invite_code, '')));
  v_name text := left(coalesce(nullif(trim(p_display_name), ''), 'あなた'), 100);
  v_avatar text := left(coalesce(nullif(trim(p_avatar), ''), '🙂'), 16);
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  if v_code = '' or char_length(v_code) > 12 then
    raise exception 'Invalid invite code';
  end if;

  delete from private.join_attempts
  where user_id = v_uid and attempted_at < now() - interval '10 minutes';

  if (
    select count(*) from private.join_attempts
    where user_id = v_uid and attempted_at > now() - interval '1 minute'
  ) >= 5 then
    raise exception 'Too many attempts. Please retry later';
  end if;

  insert into private.join_attempts (user_id) values (v_uid);

  select id into v_group_id
  from public.family_groups
  where upper(invite_code) = v_code
  limit 1;

  -- 失敗時に例外を投げると試行記録がロールバックされるため null を返す
  if v_group_id is null then
    return null;
  end if;

  if not exists (
    select 1 from public.family_members where group_id = v_group_id and user_id = v_uid
  ) and (
    select count(*) from public.family_members where group_id = v_group_id
  ) >= 10 then
    raise exception 'Family group is full';
  end if;

  select coalesce(safety_status, 'safe'), coalesce(location_note, '〇〇地区付近')
  into v_status, v_location
  from public.profiles
  where id = v_uid;

  insert into public.family_members (
    group_id, user_id, display_name, avatar, safety_status, location_note, safety_updated_at, joined_at
  )
  values (
    v_group_id, v_uid, v_name, v_avatar,
    coalesce(v_status, 'safe'), coalesce(v_location, '〇〇地区付近'), now(), now()
  )
  on conflict (group_id, user_id) do update
    set display_name = excluded.display_name,
        avatar = excluded.avatar,
        safety_status = excluded.safety_status,
        location_note = excluded.location_note,
        safety_updated_at = now(),
        joined_at = now();

  return v_group_id;
end;
$$;

revoke all on function public.join_family_group_by_code(text, text, text) from public, anon;
grant execute on function public.join_family_group_by_code(text, text, text) to authenticated;
