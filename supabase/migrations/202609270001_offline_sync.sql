-- Run once in a Supabase project. All application access goes through authenticated RPCs.
create table public.kitchen_workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) between 2 and 100),
  created_by uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
create table public.kitchen_members (
  workspace_id uuid not null references public.kitchen_workspaces(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin','member')),
  joined_at timestamptz not null default now(),
  primary key (workspace_id,user_id)
);
create table public.kitchen_invites (
  code uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.kitchen_workspaces(id) on delete cascade,
  expires_at timestamptz not null default (now() + interval '7 days')
);
create table public.kitchen_records (
  workspace_id uuid not null references public.kitchen_workspaces(id) on delete cascade,
  store text not null,
  record_id text not null,
  payload jsonb,
  version bigint not null check (version > 0),
  seq bigint not null,
  deleted boolean not null default false,
  primary key (workspace_id,store,record_id)
);
create table public.kitchen_changes (
  seq bigint generated always as identity primary key,
  workspace_id uuid not null references public.kitchen_workspaces(id) on delete cascade,
  store text not null,
  record_id text not null,
  payload jsonb,
  version bigint not null,
  deleted boolean not null,
  changed_at timestamptz not null default now()
);
create index kitchen_changes_workspace_seq on public.kitchen_changes(workspace_id,seq);
create table public.kitchen_applied_ops (
  workspace_id uuid not null references public.kitchen_workspaces(id) on delete cascade,
  operation_id uuid not null,
  result jsonb not null,
  applied_at timestamptz not null default now(),
  primary key (workspace_id,operation_id)
);

alter table public.kitchen_workspaces enable row level security;
alter table public.kitchen_members enable row level security;
alter table public.kitchen_invites enable row level security;
alter table public.kitchen_records enable row level security;
alter table public.kitchen_changes enable row level security;
alter table public.kitchen_applied_ops enable row level security;
revoke all on public.kitchen_workspaces,public.kitchen_members,public.kitchen_invites,public.kitchen_records,public.kitchen_changes,public.kitchen_applied_ops from public,anon,authenticated;
revoke all on sequence public.kitchen_changes_seq_seq from public,anon,authenticated;

create function public.kitchen_create_workspace(p_name text) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  insert into public.kitchen_workspaces(name,created_by) values (trim(p_name),auth.uid()) returning id into v_id;
  insert into public.kitchen_members(workspace_id,user_id,role) values (v_id,auth.uid(),'admin');
  return v_id;
end $$;

create function public.kitchen_list_workspaces()
returns table(id uuid,name text,role text)
language sql security definer set search_path = '' as $$
  select w.id,w.name,m.role from public.kitchen_members m
  join public.kitchen_workspaces w on w.id=m.workspace_id
  where m.user_id=auth.uid() order by w.created_at;
$$;

create function public.kitchen_create_invite(p_workspace uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_code uuid;
begin
  if not exists(select 1 from public.kitchen_members where workspace_id=p_workspace and user_id=auth.uid() and role='admin') then
    raise exception 'workspace_admin_required';
  end if;
  insert into public.kitchen_invites(workspace_id) values (p_workspace) returning code into v_code;
  return v_code;
end $$;

create function public.kitchen_join_workspace(p_code uuid) returns uuid
language plpgsql security definer set search_path = '' as $$
declare v_workspace uuid;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  delete from public.kitchen_invites where code=p_code and expires_at>now() returning workspace_id into v_workspace;
  if v_workspace is null then raise exception 'invite_invalid_or_expired'; end if;
  insert into public.kitchen_members(workspace_id,user_id,role) values (v_workspace,auth.uid(),'member') on conflict do nothing;
  return v_workspace;
end $$;

create function public.kitchen_apply_batch(p_workspace uuid,p_operation uuid,p_changes jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_change jsonb; v_store text; v_id text; v_expected bigint; v_version bigint;
  v_seq bigint; v_deleted boolean; v_payload jsonb; v_result jsonb := '[]'::jsonb;
begin
  if auth.uid() is null or not exists(select 1 from public.kitchen_members where workspace_id=p_workspace and user_id=auth.uid()) then
    raise exception 'workspace_access_denied';
  end if;
  if p_operation is null or jsonb_typeof(p_changes)<>'array' or jsonb_array_length(p_changes) not between 1 and 100 or octet_length(p_changes::text)>1048576 then
    raise exception 'invalid_sync_batch';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_workspace::text,0));
  select result into v_result from public.kitchen_applied_ops where workspace_id=p_workspace and operation_id=p_operation;
  if found then return v_result; end if;
  v_result := '[]'::jsonb;
  for v_change in select value from jsonb_array_elements(p_changes) loop
    v_store := v_change->>'store'; v_id := v_change->>'id';
    if v_store not in ('items','categories','suppliers','purchases','purchaseItems','recipes','recipeIngredients','mealPlans','mealPlanItems','transactions','priceHistory','notifications','audit','settings')
       or v_id is null or length(v_id) not between 1 and 200
       or (v_store='settings' and v_id not in ('currency','costBasis')) then
      raise exception 'invalid_sync_record';
    end if;
    v_expected := (v_change->>'expectedVersion')::bigint;
    v_deleted := coalesce((v_change->>'deleted')::boolean,false);
    v_payload := v_change->'record';
    if v_expected is null or v_expected<0 or (not v_deleted and (jsonb_typeof(v_payload)<>'object' or v_payload->>'id' is distinct from v_id)) then
      raise exception 'invalid_sync_record';
    end if;
    select version into v_version from public.kitchen_records
      where workspace_id=p_workspace and store=v_store and record_id=v_id;
    if coalesce(v_version,0)<>v_expected then
      raise exception 'sync_conflict:%:%',v_store,v_id using errcode='P0001';
    end if;
    v_version := v_expected+1;
    insert into public.kitchen_changes(workspace_id,store,record_id,payload,version,deleted)
      values(p_workspace,v_store,v_id,case when v_deleted then null else v_payload end,v_version,v_deleted) returning seq into v_seq;
    insert into public.kitchen_records(workspace_id,store,record_id,payload,version,seq,deleted)
      values(p_workspace,v_store,v_id,case when v_deleted then null else v_payload end,v_version,v_seq,v_deleted)
      on conflict(workspace_id,store,record_id) do update set
        payload=excluded.payload,version=excluded.version,seq=excluded.seq,deleted=excluded.deleted;
    v_result := v_result || jsonb_build_array(jsonb_build_object('store',v_store,'id',v_id,'version',v_version,'seq',v_seq));
  end loop;
  insert into public.kitchen_applied_ops(workspace_id,operation_id,result) values(p_workspace,p_operation,v_result);
  return v_result;
end $$;

create function public.kitchen_pull_changes(p_workspace uuid,p_after bigint default 0,p_limit integer default 200)
returns table(seq bigint,store text,record_id text,payload jsonb,version bigint,deleted boolean)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not exists(select 1 from public.kitchen_members where workspace_id=p_workspace and user_id=auth.uid()) then
    raise exception 'workspace_access_denied';
  end if;
  return query select c.seq,c.store,c.record_id,c.payload,c.version,c.deleted
    from public.kitchen_changes c where c.workspace_id=p_workspace and c.seq>greatest(coalesce(p_after,0),0)
    order by c.seq limit least(greatest(coalesce(p_limit,200),1),500);
end $$;

revoke all on function public.kitchen_create_workspace(text),public.kitchen_list_workspaces(),public.kitchen_create_invite(uuid),public.kitchen_join_workspace(uuid),public.kitchen_apply_batch(uuid,uuid,jsonb),public.kitchen_pull_changes(uuid,bigint,integer) from public,anon;
grant execute on function public.kitchen_create_workspace(text),public.kitchen_list_workspaces(),public.kitchen_create_invite(uuid),public.kitchen_join_workspace(uuid),public.kitchen_apply_batch(uuid,uuid,jsonb),public.kitchen_pull_changes(uuid,bigint,integer) to authenticated;
