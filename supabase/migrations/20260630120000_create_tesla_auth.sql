-- Tesla OAuth token storage for personal Fleet API access.
-- After completing Tesla OAuth (offline_access scope), insert one row with tokens.

create table public.tesla_auth (
    id uuid primary key default gen_random_uuid(),
    access_token text not null,
    refresh_token text not null,
    expires_at timestamptz not null,
    vin text,
    updated_at timestamptz not null default now()
);

comment on table public.tesla_auth is 'Stores Tesla Fleet API OAuth tokens for the personal iOS app.';
comment on column public.tesla_auth.refresh_token is 'Single-use; must be replaced on every token refresh.';
comment on column public.tesla_auth.vin is 'Vehicle VIN used for Fleet API calls; optional until linked.';

-- Keep updated_at current on every row change.
create or replace function public.set_tesla_auth_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

create trigger tesla_auth_set_updated_at
    before update on public.tesla_auth
    for each row
    execute function public.set_tesla_auth_updated_at();

create index tesla_auth_expires_at_idx on public.tesla_auth (expires_at);

alter table public.tesla_auth enable row level security;

create policy "Authenticated users can read tesla_auth"
    on public.tesla_auth
    for select
    to authenticated
    using (true);

create policy "Authenticated users can insert tesla_auth"
    on public.tesla_auth
    for insert
    to authenticated
    with check (true);

create policy "Authenticated users can update tesla_auth"
    on public.tesla_auth
    for update
    to authenticated
    using (true)
    with check (true);

-- Seed example (run manually after OAuth code exchange):
-- insert into public.tesla_auth (access_token, refresh_token, expires_at, vin)
-- values (
--     '<access_token>',
--     '<refresh_token>',
--     now() + interval '8 hours',
--     '<optional_vin>'
-- );
