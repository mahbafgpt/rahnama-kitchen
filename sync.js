import * as db from './db.js?v=personnel-20260928a';
import {SUPABASE_URL,SUPABASE_PUBLISHABLE_KEY} from './config.js?v=admin-20260928b';

const SESSION_KEY='rahnama-cloud-session';
const INTERVAL_MS=5*60*1000;
let activeSync=null;
let refreshRequest=null;

export const configured=()=>/^https:\/\/[^/]+\.supabase\.co\/?$/.test(SUPABASE_URL)&&SUPABASE_PUBLISHABLE_KEY.startsWith('sb_publishable_');
const base=()=>SUPABASE_URL.replace(/\/$/,'');
const readSession=()=>{try{const value=JSON.parse(localStorage.getItem(SESSION_KEY)||'null');return value?.project===base()?value:null}catch{return null}};
const saveSession=data=>{
  const session={project:base(),access_token:data.access_token,refresh_token:data.refresh_token,expires_at:Math.floor(Date.now()/1000)+(data.expires_in||3600),email:data.user?.email||readSession()?.email||''};
  localStorage.setItem(SESSION_KEY,JSON.stringify(session));return session;
};
export const cloudEmail=()=>readSession()?.email||'';
export const hasSession=()=>Boolean(readSession()?.refresh_token);

async function request(path,body,token){
  if(!configured())throw new Error('نشانی و کلید عمومی Supabase هنوز در config.js تنظیم نشده‌اند.');
  const controller=new AbortController(),timer=setTimeout(()=>controller.abort(),20000);
  let response;
  try{response=await fetch(`${base()}${path}`,{method:'POST',headers:{apikey:SUPABASE_PUBLISHABLE_KEY,'Content-Type':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify(body),signal:controller.signal})}
  catch{throw new Error('ارتباط با سرور برقرار نشد؛ تغییرها روی همین دستگاه محفوظ‌اند.')}
  finally{clearTimeout(timer)}
  let data;try{data=await response.json()}catch{data=null}
  if(!response.ok)throw new Error(data?.message||data?.error_description||data?.error||`خطای ارتباط با سرور (${response.status})`);
  return data;
}
async function accessToken(){
  const session=readSession();if(!session?.refresh_token)throw new Error('ابتدا به حساب ابری وارد شوید.');
  if(session.expires_at>Date.now()/1000+60)return session.access_token;
  if(!refreshRequest)refreshRequest=request('/auth/v1/token?grant_type=refresh_token',{refresh_token:session.refresh_token}).then(data=>saveSession(data).access_token).finally(()=>{refreshRequest=null});
  return refreshRequest;
}
const rpc=async(name,args={})=>request(`/rest/v1/rpc/${name}`,args,await accessToken());

export async function signUp(email,password){
  const data=await request('/auth/v1/signup',{email:email.trim(),password});
  if(data?.access_token)saveSession(data);
  return data;
}
export async function signIn(email,password){
  const data=await request('/auth/v1/token?grant_type=password',{email:email.trim(),password});
  saveSession(data);return data;
}
export function signOut(){localStorage.removeItem(SESSION_KEY)}
export const listWorkspaces=()=>rpc('kitchen_list_workspaces');
export const createWorkspace=name=>rpc('kitchen_create_workspace',{p_name:name.trim()});
export const joinWorkspace=code=>rpc('kitchen_join_workspace',{p_code:code.trim()});
export const createInvite=workspaceId=>rpc('kitchen_create_invite',{p_workspace:workspaceId});
export async function activateWorkspace(workspaceId,importExisting=false){
  const workspaces=await listWorkspaces();
  if(!workspaces.some(x=>x.id===workspaceId))throw new Error('به این فضای کاری دسترسی ندارید.');
  await db.enableSync(workspaceId,importExisting);
  return syncNow();
}

export async function syncNow(){
  if(activeSync)return activeSync;
  activeSync=(async()=>{
    if(!configured())return {state:'unconfigured'};
    const state=await db.syncState();
    if(!state.workspaceId)return {state:'disconnected'};
    if(!navigator.onLine)return {state:'offline',pending:state.pending};
    try{
      for(const operation of await db.pendingOperations()){
        const changes=await db.expectedChanges(operation.changes);
        const versions=await rpc('kitchen_apply_batch',{p_workspace:state.workspaceId,p_operation:operation.id,p_changes:changes});
        await db.ackOperation(operation,versions);
      }
      let cursor=(await db.syncState()).cursor;
      for(;;){
        const rows=await rpc('kitchen_pull_changes',{p_workspace:state.workspaceId,p_after:cursor,p_limit:200});
        if(!Array.isArray(rows))throw new Error('پاسخ همگام‌سازی معتبر نیست.');
        if(rows.length)cursor=rows[rows.length-1].seq;
        await db.applyRemoteChanges(rows,cursor);
        if(rows.length<200)break;
      }
      return {state:'synced',pending:0};
    }catch(error){
      const raw=String(error.message||error),conflict=raw.startsWith('sync_conflict:');
      const message=conflict?'یک داده در دستگاه دیگری نیز تغییر کرده است. دادهٔ این دستگاه محفوظ است؛ پیش از ادامه گردش موجودی و پشتیبان‌ها را بررسی کنید.':raw;
      await db.setSyncError(message);
      return {state:conflict?'conflict':'error',message,pending:(await db.syncState()).pending};
    }
  })();
  try{return await activeSync}finally{activeSync=null}
}

export function startAutoSync(onChange){
  let lastAttempt=0;
  const run=async()=>{
    if(!configured()||!hasSession()||!(await db.syncState()).workspaceId||!navigator.onLine)return;
    if(Date.now()-lastAttempt<15000)return;
    lastAttempt=Date.now();const result=await syncNow();onChange?.(result);
  };
  const onVisible=()=>{if(document.visibilityState==='visible')run()};
  window.addEventListener('online',run);document.addEventListener('visibilitychange',onVisible);
  const timer=setInterval(run,INTERVAL_MS);run();
  return ()=>{clearInterval(timer);window.removeEventListener('online',run);document.removeEventListener('visibilitychange',onVisible)};
}
