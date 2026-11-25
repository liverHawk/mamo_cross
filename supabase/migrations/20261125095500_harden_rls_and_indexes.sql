-- 1. join_family_group_by_code の実行権限を authenticated のみに制限
revoke all on function public.join_family_group_by_code(text, text, text) from public, anon;
grant execute on function public.join_family_group_by_code(text, text, text) to authenticated;

-- 2. 未インデックスの外部キーにインデックスを追加
create index if not exists idx_family_groups_created_by
  on public.family_groups (created_by);

create index if not exists idx_messages_sender_id
  on public.messages (sender_id);

-- 3. messages の重複 permissive ポリシーを統合して最適化
drop policy if exists "messages_select_public_notices" on public.messages;
drop policy if exists "messages_select_family_thread" on public.messages;
create policy "messages_select_anon_notices" on public.messages
  for select to anon
  using (kind = 'municipality_notice');

create policy "messages_select_authenticated" on public.messages
  for select to authenticated
  using (
    kind = 'municipality_notice'
    or (
      kind = 'family_thread'
      and group_id = any(private.user_family_group_ids())
    )
  );

drop policy if exists "messages_insert_family_thread" on public.messages;
drop policy if exists "messages_insert_municipality_notice" on public.messages;
create policy "messages_insert_anon_notices" on public.messages
  for insert to anon
  with check (kind = 'municipality_notice');

create policy "messages_insert_authenticated" on public.messages
  for insert to authenticated
  with check (
    kind = 'municipality_notice'
    or (
      kind = 'family_thread'
      and sender_id = (select auth.uid())
      and group_id = any(private.user_family_group_ids())
    )
  );