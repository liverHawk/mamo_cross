-- デモ・シードデータの住所・施設名を山口県内の実在住所へ更新

-- 1. rescue_requests 初期デモ行の更新
update public.rescue_requests
set location = '山口県山口市亀山町2-1付近',
    location_text = '山口県山口市亀山町2-1付近'
where request_id = 'mamo-0005' and (location like '%○○%' or location_text like '%○○%');

update public.rescue_requests
set location = '山口県下関市南部町1-1付近',
    location_text = '山口県下関市南部町1-1付近'
where request_id = 'mamo-0004' and (location like '%○○%' or location_text like '%○○%');

update public.rescue_requests
set location = '山口県萩市大字江向510付近',
    location_text = '山口県萩市大字江向510付近'
where request_id = 'mamo-0003' and (location like '%○○%' or location_text like '%○○%');

update public.rescue_requests
set location = '山口県宇部市常盤町1-7-1付近',
    location_text = '山口県宇部市常盤町1-7-1付近'
where request_id = 'mamo-0002' and (location like '%○○%' or location_text like '%○○%');

update public.rescue_requests
set location = '山口県岩国市今津町1-14-51付近',
    location_text = '山口県岩国市今津町1-14-51付近'
where request_id = 'mamo-0001' and (location like '%○○%' or location_text like '%○○%');

-- 2. shelters 初期シードの更新
update public.shelters
set name = '大殿地区 大殿小学校',
    address = '山口県山口市大殿大路120'
where id = 'shelter_1' and (name like '%〇〇%' or address like '%〇〇%');

update public.shelters
set name = '湯田地域交流センター（福祉避難所）',
    address = '山口県山口市湯田温泉5-5-15'
where id = 'shelter_2' and (name like '%〇〇%' or address like '%〇〇%');

update public.shelters
set name = '亀山公園（一時避難場所）',
    address = '山口県山口市亀山町2-1'
where id = 'shelter_3' and (name like '%〇〇%' or address like '%〇〇%');

-- 3. hazard_spots 初期シードの更新
update public.hazard_spots
set description = '大殿小学校西側の通学路沿い・迂回推奨'
where id = 'hazard_1' and description like '%〇〇%';

update public.hazard_spots
set description = '一の坂川沿いアンダーパス通行不可'
where id = 'hazard_2' and description like '%〇〇%';

-- 4. messages 初期シードの更新
update public.messages
set sender_name = '山口市 災害対策本部',
    body = '【緊急】山口市大殿地区で震度5強を観測しました。大殿地区 大殿小学校ほか2箇所の避難所を開設しています。'
where id = '00000000-0000-0000-0000-000000000001'
  and (sender_name like '%〇〇%' or body like '%〇〇%');

update public.messages
set sender_name = '山口市 防災無線',
    body = '大殿小学校にて給水および非常電源の提供を開始しました。余震にご注意ください。'
where id = '00000000-0000-0000-0000-000000000002'
  and (sender_name like '%〇〇%' or body like '%〇〇%');

-- 5. profiles / family_members のデフォルト location_note を山口県山口市へ変更
alter table public.profiles
  alter column location_note set default '山口県山口市亀山町付近';

update public.profiles
set location_note = '山口県山口市亀山町付近'
where location_note = '〇〇地区付近';

update public.family_members
set location_note = '山口県山口市亀山町付近'
where location_note = '〇〇地区付近';

-- 6. RPC 内のフォールバック location_note を更新
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
  v_location text := '山口県山口市亀山町付近';
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

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(v_uid::text, 0)
  );

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

  select display_name, coalesce(safety_status, 'safe'), coalesce(location_note, '山口県山口市亀山町付近')
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
    coalesce(v_location, '山口県山口市亀山町付近'),
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
  v_location text := '山口県山口市亀山町付近';
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

  select coalesce(safety_status, 'safe'), coalesce(location_note, '山口県山口市亀山町付近')
  into v_status, v_location
  from public.profiles
  where id = v_uid;

  insert into public.family_members (
    group_id, user_id, display_name, avatar, safety_status, location_note, safety_updated_at, joined_at
  )
  values (
    v_group_id, v_uid, v_name, v_avatar,
    coalesce(v_status, 'safe'), coalesce(v_location, '山口県山口市亀山町付近'), now(), now()
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
