-- 1. private スキーマおよび内部ヘルパー関数の権限厳格化 (Critical #1)
grant usage on schema private to authenticated;
revoke all on function private.user_family_group_ids() from public, anon;
grant execute on function private.user_family_group_ids() to authenticated;
revoke all on function private.sync_profile_to_family_members() from public, anon, authenticated;

-- 2. デフォルト家族グループ取得・作成の原子化 RPC (High #3 / Medium #13)
create or replace function public.create_default_family_group(
  p_group_name text default 'マイ家族グループ',
  p_display_name text default 'あなた',
  p_avatar text default '🙂'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := (select auth.uid());
  v_group record;
  v_profile_name text;
  v_status text := 'safe';
  v_location text := '〇〇地区付近';
  v_display_name text;
  v_group_name text;
  v_avatar text;
  v_chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code text;
  v_attempt int;
  i int;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select fg.id, fg.name, fg.invite_code, fg.created_by, fg.created_at
  into v_group
  from public.family_members fm
  join public.family_groups fg on fg.id = fm.group_id
  where fm.user_id = v_uid
  order by fm.joined_at desc, fm.safety_updated_at desc
  limit 1;

  if found then
    return jsonb_build_object(
      'id', v_group.id,
      'name', v_group.name,
      'invite_code', v_group.invite_code,
      'created_by', v_group.created_by,
      'created_at', v_group.created_at
    );
  end if;

  select display_name, coalesce(safety_status, 'safe'), coalesce(location_note, '〇〇地区付近')
  into v_profile_name, v_status, v_location
  from public.profiles
  where id = v_uid;

  v_display_name := coalesce(nullif(trim(p_display_name), ''), nullif(trim(v_profile_name), ''), 'あなた');
  v_group_name := coalesce(nullif(trim(p_group_name), ''), 'マイ家族グループ');
  v_avatar := coalesce(nullif(trim(p_avatar), ''), '🙂');

  for v_attempt in 1..10 loop
    v_code := '';
    for i in 1..6 loop
      v_code := v_code || pg_catalog.substr(
        v_chars,
        pg_catalog.floor(pg_catalog.random() * pg_catalog.length(v_chars))::int + 1,
        1
      );
    end loop;

    begin
      insert into public.family_groups (name, invite_code, created_by)
      values (v_group_name, v_code, v_uid)
      returning id, name, invite_code, created_by, created_at
      into v_group;
      exit;
    exception when unique_violation then
      if v_attempt = 10 then
        raise exception 'Failed to generate unique invite code';
      end if;
    end;
  end loop;

  insert into public.family_members (
    group_id, user_id, display_name, avatar, role, safety_status, location_note, safety_updated_at, joined_at
  )
  values (
    v_group.id,
    v_uid,
    v_display_name,
    v_avatar,
    'owner',
    coalesce(v_status, 'safe'),
    coalesce(v_location, '〇〇地区付近'),
    now(),
    now()
  )
  on conflict (group_id, user_id) do update
    set display_name = excluded.display_name,
        avatar = excluded.avatar,
        safety_status = excluded.safety_status,
        location_note = excluded.location_note,
        safety_updated_at = now();

  return jsonb_build_object(
    'id', v_group.id,
    'name', v_group.name,
    'invite_code', v_group.invite_code,
    'created_by', v_group.created_by,
    'created_at', v_group.created_at
  );
end;
$$;

revoke all on function public.create_default_family_group(text, text, text) from public, anon;
grant execute on function public.create_default_family_group(text, text, text) to authenticated;

-- 3. join_family_group_by_code の入力検証強化・再参加時 joined_at 更新（role は維持）
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

  if nullif(trim(p_invite_code), '') is null then
    raise exception 'Invite code is required';
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
    group_id, user_id, display_name, avatar, safety_status, location_note, safety_updated_at, joined_at
  )
  values (
    v_group_id,
    v_uid,
    coalesce(nullif(trim(p_display_name), ''), 'あなた'),
    coalesce(nullif(trim(p_avatar), ''), '🙂'),
    coalesce(v_status, 'safe'),
    coalesce(v_location, '〇〇地区付近'),
    now(),
    now()
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

-- 4. family_groups / family_members の直接 INSERT 禁止・列レベル UPDATE 制限・不変列トリガー保護 (High #3)
drop policy if exists "family_members_insert_self" on public.family_members;
drop policy if exists "family_groups_insert_authenticated" on public.family_groups;
revoke insert on public.family_members from anon, authenticated;
revoke insert on public.family_groups from anon, authenticated;

revoke update on public.family_members from anon, authenticated;
grant update (display_name, avatar, safety_status, location_note, safety_updated_at)
  on public.family_members to authenticated;

create or replace function private.guard_family_members_immutable_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.group_id is distinct from old.group_id
     or new.user_id is distinct from old.user_id
     or new.role is distinct from old.role then
    raise exception 'Cannot modify immutable columns of family_members';
  end if;
  return new;
end;
$$;

revoke all on function private.guard_family_members_immutable_columns() from public, anon, authenticated;

drop trigger if exists trg_guard_family_members_immutable_columns on public.family_members;
create trigger trg_guard_family_members_immutable_columns
  before update on public.family_members
  for each row
  execute function private.guard_family_members_immutable_columns();

drop policy if exists "family_members_update_self" on public.family_members;
create policy "family_members_update_self" on public.family_members
  for update to authenticated
  using (user_id = (select auth.uid()))
  with check (
    user_id = (select auth.uid())
    and group_id = any((select private.user_family_group_ids())::uuid[])
  );

-- SELECT ポリシーも initPlan 形式で最適化
drop policy if exists "family_groups_select_member_or_creator" on public.family_groups;
create policy "family_groups_select_member_or_creator" on public.family_groups
  for select to authenticated
  using (
    created_by = (select auth.uid())
    or id = any((select private.user_family_group_ids())::uuid[])
  );

drop policy if exists "family_members_select_same_group" on public.family_members;
create policy "family_members_select_same_group" on public.family_members
  for select to authenticated
  using (
    user_id = (select auth.uid())
    or group_id = any((select private.user_family_group_ids())::uuid[])
  );

drop policy if exists "messages_select_authenticated" on public.messages;
create policy "messages_select_authenticated" on public.messages
  for select to authenticated
  using (
    kind = 'municipality_notice'
    or (
      kind = 'family_thread'
      and group_id = any((select private.user_family_group_ids())::uuid[])
    )
  );

-- 5. messages の自治体お知らせ偽装防止 (High #4)
drop policy if exists "messages_insert_anon_notices" on public.messages;
drop policy if exists "messages_insert_municipality_notice" on public.messages;
drop policy if exists "messages_insert_authenticated" on public.messages;
drop policy if exists "messages_insert_family_thread" on public.messages;

create policy "messages_insert_family_thread" on public.messages
  for insert to authenticated
  with check (
    kind = 'family_thread'
    and group_id is not null
    and sender_id = (select auth.uid())
    and group_id = any((select private.user_family_group_ids())::uuid[])
  );

revoke insert on public.messages from anon;

-- 6. shelters / hazard_spots の匿名・クライアント更新禁止 (High #5)
drop policy if exists "shelters_update_all" on public.shelters;
revoke insert, update, delete on public.shelters from anon, authenticated;
revoke insert, update, delete on public.hazard_spots from anon, authenticated;
