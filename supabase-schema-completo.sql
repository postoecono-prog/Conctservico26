-- CONECTA SERVIÇOS V2: execute no SQL Editor do Supabase.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 full_name text not null, email text, phone text not null, city text not null,
 role text not null default 'client' check (role in ('client','professional','admin')),
 status text not null default 'active' check (status in ('active','pending','suspended')),
 service_category text, subscription_until timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.service_requests (
 id uuid primary key default gen_random_uuid(), client_id uuid not null references public.profiles(id) on delete cascade,
 professional_id uuid not null references public.profiles(id) on delete cascade,
 service text not null check (char_length(service) between 2 and 120),
 description text not null check (char_length(description) between 5 and 3000),
 status text not null default 'pending' check (status in ('pending','accepted','rejected','completed','cancelled')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists profiles_role_status_idx on public.profiles(role,status);
create index if not exists profiles_subscription_idx on public.profiles(subscription_until);
create index if not exists requests_client_idx on public.service_requests(client_id);
create index if not exists requests_professional_idx on public.service_requests(professional_id);
create or replace function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles for each row execute function public.set_updated_at();
drop trigger if exists requests_updated_at on public.service_requests;
create trigger requests_updated_at before update on public.service_requests for each row execute function public.set_updated_at();
alter table public.profiles enable row level security;
alter table public.service_requests enable row level security;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=auth.uid() and role='admin' and status='active'); $$;
create or replace function public.is_active_professional(pro_id uuid) returns boolean language sql stable security definer set search_path=public as $$ select exists(select 1 from public.profiles where id=pro_id and role='professional' and status='active' and subscription_until > now()); $$;
drop policy if exists profiles_select_authenticated on public.profiles;
create policy profiles_select_authenticated on public.profiles for select to authenticated using (id=auth.uid() or public.is_admin() or (role='professional' and status='active' and subscription_until > now()));
drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self on public.profiles for insert to authenticated with check (id=auth.uid() and role in ('client','professional'));
drop policy if exists profiles_update_self_or_admin on public.profiles;
create policy profiles_update_self_or_admin on public.profiles for update to authenticated using (id=auth.uid() or public.is_admin()) with check ((id=auth.uid() and role in ('client','professional')) or public.is_admin());
drop policy if exists requests_select_related on public.service_requests;
create policy requests_select_related on public.service_requests for select to authenticated using (client_id=auth.uid() or (professional_id=auth.uid() and public.is_active_professional(professional_id)) or public.is_admin());
drop policy if exists requests_insert_active_client on public.service_requests;
create policy requests_insert_active_client on public.service_requests for insert to authenticated with check (client_id=auth.uid() and public.is_active_professional(professional_id));
drop policy if exists requests_update_related on public.service_requests;
create policy requests_update_related on public.service_requests for update to authenticated using (client_id=auth.uid() or (professional_id=auth.uid() and public.is_active_professional(professional_id)) or public.is_admin()) with check (client_id=auth.uid() or (professional_id=auth.uid() and public.is_active_professional(professional_id)) or public.is_admin());
create or replace function public.admin_activate_professional(professional_id uuid, days integer default 30) returns timestamptz language plpgsql security definer set search_path=public as $$
declare new_until timestamptz;
begin
 if not public.is_admin() then raise exception 'Acesso negado'; end if;
 if days < 1 or days > 365 then raise exception 'Período inválido'; end if;
 new_until := now() + make_interval(days => days);
 update public.profiles set status='active', subscription_until=new_until, updated_at=now() where id=professional_id and role='professional';
 if not found then raise exception 'Profissional não encontrado'; end if;
 return new_until;
end; $$;
revoke all on function public.admin_activate_professional(uuid,integer) from public;
grant execute on function public.admin_activate_professional(uuid,integer) to authenticated;
-- Depois de criar o primeiro usuário e fazer login, transforme-o em admin:
-- update public.profiles set role='admin', status='active' where email='SEU_EMAIL_ADMIN@EXEMPLO.COM';
