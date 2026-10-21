-- v10 · Four-tier roles (Superadmin / Admin / Custom / Guest) + reviewer-list fix
-- ----------------------------------------------------------------------------
-- What this does:
--   1. Backs up the members table to public.members_backup_v10 (first run only).
--   2. Adds members.added_by (who added the person; an Admin may change only
--      the Custom/Guest members they added).
--   3. Sets the roles:  Superadmin = yen.tran, binh.nguyen, nguyen.che
--                       Admin      = vy.le, congthanh.bui, phuong.ntl, hoa.doan
--                       Guest      = every non-@pizza4ps.com email
--                       Custom     = everyone else
--      Anyone who was admin before but is not a Superadmin keeps Edit on every
--      pillar (as Custom) so nobody is locked out; adjust them afterwards.
--   4. Replaces the row-level security on `members`:
--        - Superadmin/Admin/Custom can READ the member list (fixes "No reviewers")
--        - Guests read only their own row
--        - Superadmin writes everything; Admin writes only Custom/Guest rows
--          they added (added_by = themselves)
--   5. Lets Admins VIEW every document (extra read policy on `documents`).
--   6. Adds share_with_guest(): any editor of a document can share it view-only
--      with a Guest; the function checks the caller can edit that document.
--
-- Run in Supabase ▸ SQL Editor ▸ New query ▸ Run. Safe to re-run.

begin;

-- 0. Sanity checks: pillars/items must be jsonb (the app stores objects there).
do $$
declare t1 text; t2 text;
begin
  select data_type into t1 from information_schema.columns where table_schema='public' and table_name='members' and column_name='pillars';
  select data_type into t2 from information_schema.columns where table_schema='public' and table_name='members' and column_name='items';
  if t1 is distinct from 'jsonb' or t2 is distinct from 'jsonb' then
    raise exception 'members.pillars / members.items are % / % (expected jsonb). Stop and send this message to the developer.', t1, t2;
  end if;
end $$;

-- 1. Backup (only the first time)
do $$
begin
  if to_regclass('public.members_backup_v10') is null then
    execute 'create table public.members_backup_v10 as select * from public.members';
  end if;
end $$;

-- 2. Column + loosen any old role constraint (new role names must be allowed)
alter table public.members add column if not exists added_by text;
do $$
declare r record;
begin
  for r in select policyname from pg_policies where schemaname = 'public' and tablename = 'members' loop
    execute format('drop policy %I on public.members', r.policyname);
  end loop;
  if (select data_type from information_schema.columns
       where table_schema='public' and table_name='members' and column_name='role') <> 'text' then
    execute 'alter table public.members alter column role type text using role::text';
  end if;
end $$;
do $$
declare c record;
begin
  for c in select conname from pg_constraint
           where conrelid = 'public.members'::regclass and contype = 'c'
             and pg_get_constraintdef(oid) ilike '%role%' loop
    execute format('alter table public.members drop constraint %I', c.conname);
  end loop;
end $$;

-- 3. Roles
insert into public.members (email, name, role, admin, pillars, items)
values ('yen.tran@pizza4ps.com',   'Yen Tran',   'Superadmin', true, '{}'::jsonb, '{}'::jsonb),
       ('binh.nguyen@pizza4ps.com','Binh Nguyen','Superadmin', true, '{}'::jsonb, '{}'::jsonb),
       ('nguyen.che@pizza4ps.com', 'Nguyen Che', 'Superadmin', true, '{}'::jsonb, '{}'::jsonb)
on conflict (email) do update set role = 'Superadmin', admin = true;

insert into public.members (email, name, role, admin, pillars, items)
values ('vy.le@pizza4ps.com',         'Vy Le',         'Admin', false, '{}'::jsonb, '{}'::jsonb),
       ('congthanh.bui@pizza4ps.com', 'Congthanh Bui', 'Admin', false, '{}'::jsonb, '{}'::jsonb),
       ('phuong.ntl@pizza4ps.com',    'Phuong Ntl',    'Admin', false, '{}'::jsonb, '{}'::jsonb),
       ('hoa.doan@pizza4ps.com',      'Hoa Doan',      'Admin', false, '{}'::jsonb, '{}'::jsonb)
on conflict (email) do update set role = 'Admin', admin = false;

-- former admins who are not Superadmin: keep Edit everywhere, as Custom
update public.members
   set role = 'Custom', admin = false,
       pillars = '{"elearning":"edit","data":"edit","logistics":"edit","training":"edit","career":"edit"}'::jsonb
 where admin = true
   and lower(email) not in ('yen.tran@pizza4ps.com','binh.nguyen@pizza4ps.com','nguyen.che@pizza4ps.com');

-- outside emails -> Guest (view-only, individually shared documents)
update public.members
   set role = 'Guest', admin = false, pillars = '{}'::jsonb
 where lower(email) not like '%@pizza4ps.com';

-- everyone else with an old role name -> Custom
update public.members
   set role = 'Custom'
 where role is null or role not in ('Superadmin','Admin','Custom','Guest');

-- 4. Helper functions (security definer so they can read members under RLS)
create or replace function public.lnd_my_email() returns text
language sql stable as $$
  select lower(coalesce(auth.jwt() ->> 'email', ''))
$$;

create or replace function public.lnd_my_role() returns text
language sql stable security definer set search_path = public as $$
  select case when m.admin then 'Superadmin'
              when m.role in ('Admin','Custom','Guest') then m.role
              when lower(m.email) like '%@pizza4ps.com' then 'Custom'
              else 'Guest' end
    from public.members m
   where lower(m.email) = public.lnd_my_email()
   limit 1
$$;

-- 5. members RLS (old policies were dropped in step 2)
alter table public.members enable row level security;

create policy members_select on public.members for select to authenticated
  using ( lower(email) = public.lnd_my_email()
          or public.lnd_my_role() in ('Superadmin','Admin','Custom') );

create policy members_insert on public.members for insert to authenticated
  with check ( public.lnd_my_role() = 'Superadmin'
               or ( public.lnd_my_role() = 'Admin' and admin = false
                    and role in ('Custom','Guest') and lower(added_by) = public.lnd_my_email() ) );

create policy members_update on public.members for update to authenticated
  using ( public.lnd_my_role() = 'Superadmin'
          or ( public.lnd_my_role() = 'Admin' and admin = false
               and role in ('Custom','Guest') and lower(added_by) = public.lnd_my_email() ) )
  with check ( public.lnd_my_role() = 'Superadmin'
               or ( public.lnd_my_role() = 'Admin' and admin = false
                    and role in ('Custom','Guest') and lower(added_by) = public.lnd_my_email() ) );

create policy members_delete on public.members for delete to authenticated
  using ( public.lnd_my_role() = 'Superadmin'
          or ( public.lnd_my_role() = 'Admin' and admin = false
               and role in ('Custom','Guest') and lower(added_by) = public.lnd_my_email() ) );

-- 6. Admins can view every document (adds to, never narrows, existing policies)
drop policy if exists documents_admin_view_all on public.documents;
create policy documents_admin_view_all on public.documents for select to authenticated
  using ( public.lnd_my_role() = 'Admin' );

-- 7. Share a document with a Guest (view-only). p_level: 'view' or 'none'.
create or replace function public.share_with_guest(p_email text, p_process_id text, p_level text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me  public.members;
  d   public.documents;
  g   public.members;
  e   text := lower(trim(p_email));
  lvl text;
  bu  text;
begin
  if p_level not in ('view','none') then raise exception 'Invalid level'; end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'Invalid email'; end if;

  select * into me from public.members where lower(email) = public.lnd_my_email() limit 1;
  if me.email is null then raise exception 'You are not a member'; end if;

  select * into d from public.documents where process_id::text = p_process_id limit 1;
  if d.process_id is null then raise exception 'Document not found'; end if;

  -- same order as the app: pillar -> career business unit -> single document
  if me.admin then
    lvl := 'edit';
  elsif public.lnd_my_role() = 'Guest' then
    lvl := 'view';
  else
    lvl := coalesce(me.pillars ->> d.pillar, 'none');
    if d.pillar = 'career' then
      bu := '@career:' || coalesce(nullif(d.draft ->> 'country',''), 'Vietnam') || '::' || coalesce(d.draft ->> 'bu','');
      lvl := coalesce(me.items ->> bu, lvl);
    end if;
    lvl := coalesce(me.items ->> p_process_id, lvl);
  end if;
  if lvl <> 'edit' then raise exception 'Only editors of this document can share it'; end if;

  select * into g from public.members where lower(email) = e limit 1;
  if g.email is null then
    if p_level = 'none' then return jsonb_build_object('ok', true); end if;
    insert into public.members (email, name, role, admin, pillars, items, added_by)
    values (e, initcap(replace(replace(split_part(e,'@',1),'.',' '),'_',' ')), 'Guest', false,
            '{}'::jsonb, jsonb_build_object(p_process_id, 'view'), public.lnd_my_email());
  else
    if g.admin or coalesce(g.role,'') <> 'Guest' then
      raise exception '% is a team member, not a guest. Ask a Superadmin or Admin to set their access.', e;
    end if;
    if p_level = 'none' then
      update public.members set items = coalesce(items,'{}'::jsonb) - p_process_id where email = g.email;
    else
      update public.members set items = coalesce(items,'{}'::jsonb) || jsonb_build_object(p_process_id, 'view') where email = g.email;
    end if;
  end if;

  begin
    insert into public.audit_log (actor, action, process_id, title, detail)
    values (public.lnd_my_email(), 'guest_share', p_process_id, d.title, e || ' -> ' || p_level);
  exception when others then null;   -- audit is best-effort
  end;

  return jsonb_build_object('ok', true);
end $$;

revoke all on function public.share_with_guest(text, text, text) from public, anon;
grant execute on function public.share_with_guest(text, text, text) to authenticated;
grant execute on function public.lnd_my_role() to authenticated;
grant execute on function public.lnd_my_email() to authenticated;

commit;

-- Check the result:
--   select email, role, admin, added_by from public.members order by role, email;
--
-- Undo (restores the old member rows; the old policies must be re-created by hand):
--   truncate public.members; insert into public.members select b.*, null from public.members_backup_v10 b;
