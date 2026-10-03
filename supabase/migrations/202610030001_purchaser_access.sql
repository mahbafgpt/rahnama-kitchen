begin;

create or replace function public.kitchen_apply_batch(p_workspace uuid,p_operation uuid,p_changes jsonb) returns jsonb
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
    if v_store not in ('users','userRoles','items','categories','suppliers','purchaseRoutines','purchaseLists','purchaseListItems','purchases','purchaseItems','recipes','recipeIngredients','mealPlans','mealPlanItems','personnel','mealDeliveries','transactions','priceHistory','notifications','audit','settings')
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

revoke all on function public.kitchen_apply_batch(uuid,uuid,jsonb) from public,anon;
grant execute on function public.kitchen_apply_batch(uuid,uuid,jsonb) to authenticated;

commit;
