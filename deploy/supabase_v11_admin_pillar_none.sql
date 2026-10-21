-- v11 · Admin views every pillar EXCEPT pillars a Superadmin set to "None"
-- ----------------------------------------------------------------------------
-- Replaces the v10 policy documents_admin_view_all. Same order as the app:
--   pillar level (missing = view) -> career business unit -> single document.
-- So a document set to "View" for an Admin still shows inside a "None" pillar.
--
-- Run in Supabase ▸ SQL Editor ▸ New query ▸ Run. Safe to re-run.

begin;

create or replace function public.lnd_admin_can_view(p_pillar text, p_process_id text, p_content jsonb)
returns boolean
language plpgsql stable security definer set search_path = public as $$
declare
  m   public.members;
  lvl text;
  bu  text;
begin
  select * into m from public.members where lower(email) = public.lnd_my_email() limit 1;
  if m.email is null or m.admin or coalesce(m.role,'') <> 'Admin' then return false; end if;
  lvl := coalesce(m.pillars ->> p_pillar, 'view');
  if p_pillar = 'career' then
    bu := '@career:' || coalesce(nullif(p_content ->> 'country',''), 'Vietnam') || '::' || coalesce(p_content ->> 'bu','');
    lvl := coalesce(m.items ->> bu, lvl);
  end if;
  lvl := coalesce(m.items ->> p_process_id, lvl);
  return lvl <> 'none';
end $$;

grant execute on function public.lnd_admin_can_view(text, text, jsonb) to authenticated;

drop policy if exists documents_admin_view_all on public.documents;
create policy documents_admin_view_all on public.documents for select to authenticated
  using ( public.lnd_admin_can_view(pillar, process_id::text, coalesce(draft, published)) );

commit;
