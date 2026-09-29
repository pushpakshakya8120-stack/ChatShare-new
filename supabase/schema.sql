create extension if not exists "uuid-ossp";

create table if not exists profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text unique not null,
  username text unique,
  full_name text,
  avatar_url text,
  bio text default '',
  is_master boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists subscriptions (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  plan text not null check (plan in ('monthly','six_month')),
  status text not null default 'active' check (status in ('active','expired','cancelled')),
  starts_at timestamptz default now(),
  expires_at timestamptz not null,
  created_at timestamptz default now()
);

create table if not exists posts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  caption text default '',
  media_url text,
  media_type text check (media_type in ('image','video','none')) default 'none',
  created_at timestamptz default now()
);

create table if not exists likes (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  unique(post_id,user_id)
);

create table if not exists comments (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  text text not null,
  created_at timestamptz default now()
);

create table if not exists follows (
  id uuid primary key default uuid_generate_v4(),
  follower_id uuid references profiles(id) on delete cascade,
  following_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  unique(follower_id,following_id),
  check(follower_id <> following_id)
);

create table if not exists conversations (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now()
);

create table if not exists conversation_members (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid references conversations(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  unique(conversation_id,user_id)
);

create table if not exists messages (
  id uuid primary key default uuid_generate_v4(),
  conversation_id uuid references conversations(id) on delete cascade,
  sender_id uuid references profiles(id) on delete cascade,
  text text default '',
  media_url text,
  media_type text check(media_type in ('image','video','none')) default 'none',
  is_view_once boolean default false,
  created_at timestamptz default now()
);

create table if not exists notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  actor_id uuid references profiles(id) on delete cascade,
  type text not null,
  post_id uuid references posts(id) on delete cascade,
  message text default '',
  is_read boolean default false,
  created_at timestamptz default now()
);

create table if not exists stories (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  media_url text not null,
  media_type text not null,
  expires_at timestamptz not null,
  created_at timestamptz default now()
);

create table if not exists reels (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid references profiles(id) on delete cascade,
  video_url text not null,
  caption text default '',
  created_at timestamptz default now()
);

create table if not exists media_views (
  id uuid primary key default uuid_generate_v4(),
  message_id uuid references messages(id) on delete cascade,
  viewer_id uuid references profiles(id) on delete cascade,
  viewed_at timestamptz default now(),
  unique(message_id,viewer_id)
);

create index if not exists posts_user_idx on posts(user_id);
create index if not exists posts_created_idx on posts(created_at desc);
create index if not exists messages_conversation_idx on messages(conversation_id,created_at);
create index if not exists notifications_user_idx on notifications(user_id,created_at desc);
create index if not exists follows_follower_idx on follows(follower_id);
create index if not exists follows_following_idx on follows(following_id);

alter table profiles enable row level security;
alter table posts enable row level security;
alter table likes enable row level security;
alter table comments enable row level security;
alter table follows enable row level security;
alter table conversations enable row level security;
alter table conversation_members enable row level security;
alter table messages enable row level security;
alter table notifications enable row level security;
alter table stories enable row level security;
alter table reels enable row level security;
alter table subscriptions enable row level security;
alter table media_views enable row level security;

drop policy if exists profiles_select on profiles;
create policy profiles_select on profiles for select to authenticated using (true);

drop policy if exists profiles_insert on profiles;
create policy profiles_insert on profiles for insert to authenticated with check (auth.uid() = id);

drop policy if exists profiles_update on profiles;
create policy profiles_update on profiles for update to authenticated using (auth.uid() = id) with check (auth.uid() = id);

drop policy if exists posts_select on posts;
create policy posts_select on posts for select to authenticated using (true);

drop policy if exists posts_insert on posts;
create policy posts_insert on posts for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists posts_update on posts;
create policy posts_update on posts for update to authenticated using (auth.uid() = user_id);

drop policy if exists posts_delete on posts;
create policy posts_delete on posts for delete to authenticated using (auth.uid() = user_id);

drop policy if exists likes_select on likes;
create policy likes_select on likes for select to authenticated using (true);

drop policy if exists likes_insert on likes;
create policy likes_insert on likes for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists likes_delete on likes;
create policy likes_delete on likes for delete to authenticated using (auth.uid() = user_id);

drop policy if exists comments_select on comments;
create policy comments_select on comments for select to authenticated using (true);

drop policy if exists comments_insert on comments;
create policy comments_insert on comments for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists comments_delete on comments;
create policy comments_delete on comments for delete to authenticated using (auth.uid() = user_id);

drop policy if exists follows_select on follows;
create policy follows_select on follows for select to authenticated using (true);

drop policy if exists follows_insert on follows;
create policy follows_insert on follows for insert to authenticated with check (auth.uid() = follower_id);

drop policy if exists follows_delete on follows;
create policy follows_delete on follows for delete to authenticated using (auth.uid() = follower_id);

drop policy if exists subscriptions_select on subscriptions;
create policy subscriptions_select on subscriptions for select to authenticated using (auth.uid() = user_id);

drop policy if exists conversations_select on conversations;
create policy conversations_select on conversations for select to authenticated using (
  exists(select 1 from conversation_members cm where cm.conversation_id = conversations.id and cm.user_id = auth.uid())
);

drop policy if exists members_select on conversation_members;
create policy members_select on conversation_members for select to authenticated using (
  user_id = auth.uid() or exists(select 1 from conversation_members cm where cm.conversation_id = conversation_members.conversation_id and cm.user_id = auth.uid())
);

drop policy if exists members_insert on conversation_members;
create policy members_insert on conversation_members for insert to authenticated with check (user_id = auth.uid());

drop policy if exists messages_select on messages;
create policy messages_select on messages for select to authenticated using (
  exists(select 1 from conversation_members cm where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid())
);

drop policy if exists messages_insert on messages;
create policy messages_insert on messages for insert to authenticated with check (
  auth.uid() = sender_id and exists(select 1 from conversation_members cm where cm.conversation_id = messages.conversation_id and cm.user_id = auth.uid())
);

drop policy if exists messages_update on messages;
create policy messages_update on messages for update to authenticated using (sender_id = auth.uid());

drop policy if exists notifications_select on notifications;
create policy notifications_select on notifications for select to authenticated using (user_id = auth.uid());

drop policy if exists notifications_update on notifications;
create policy notifications_update on notifications for update to authenticated using (user_id = auth.uid());

drop policy if exists stories_select on stories;
create policy stories_select on stories for select to authenticated using (expires_at > now());

drop policy if exists stories_insert on stories;
create policy stories_insert on stories for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists stories_delete on stories;
create policy stories_delete on stories for delete to authenticated using (auth.uid() = user_id);

drop policy if exists reels_select on reels;
create policy reels_select on reels for select to authenticated using (true);

drop policy if exists reels_insert on reels;
create policy reels_insert on reels for insert to authenticated with check (auth.uid() = user_id);

drop policy if exists media_views_insert on media_views;
create policy media_views_insert on media_views for insert to authenticated with check (auth.uid() = viewer_id);

alter table posts replica identity full;
alter table messages replica identity full;
alter table comments replica identity full;
alter table follows replica identity full;
alter table notifications replica identity full;
alter table profiles replica identity full;
alter table stories replica identity full;

do $$
begin
  alter publication supabase_realtime add table posts;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table messages;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table comments;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table follows;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table notifications;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table profiles;
exception when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table stories;
exception when duplicate_object then null;
end $$;

insert into profiles(id,email,username,full_name,is_master)
select id,email,'master','ChatShare Master',true
from auth.users
where email='pushpakshakya8120@gmail.com'
on conflict(id) do update set is_master=true;

cat > .env.example <<'ENV'
VITE_SUPABASE_URL=YOUR_SUPABASE_PROJECT_URL
VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY
ENV

cat > src/services/chatshare.js <<'JS'
import { createClient } from "@supabase/supabase-js";

const url = import.meta.env.VITE_SUPABASE_URL;
const key = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = url && key ? createClient(url,key) : null;

export async function sendEmailOtp(email){
  if(!supabase) throw new Error("Supabase is not configured.");
  return supabase.auth.signInWithOtp({
    email: email.trim(),
    options:{shouldCreateUser:true}
  });
}

export async function verifyEmailOtp(email,token){
  if(!supabase) throw new Error("Supabase is not configured.");
  return supabase.auth.verifyOtp({
    email:email.trim(),
    token,
    type:"email"
  });
}

export async function getProfile(userId){
  if(!supabase) return {data:null,error:null};
  return supabase.from("profiles").select("*").eq("id",userId).maybeSingle();
}

export async function saveProfile(profile){
  if(!supabase) throw new Error("Supabase is not configured.");
  return supabase.from("profiles").upsert(profile,{onConflict:"id"});
}

export function subscribeToTable(table,callback){
  if(!supabase) return ()=>{};
  const channel=supabase.channel(`chatshare-${table}-${Date.now()}`)
    .on("postgres_changes",{event:"*",schema:"public",table},callback)
    .subscribe();
  return ()=>supabase.removeChannel(channel);
}
JS

cat > src/features.js <<'JS'
export const CHATSHARE_FEATURES = {
  auth: ["email verification OTP","existing account recovery","profile setup","secure logout"],
  social: ["posts","likes","comments","followers","following","profile","search"],
  messaging: ["real-time conversations","real-time messages","normal media","view-once media"],
  discovery: ["stories","reels","notifications"],
  account: ["settings","subscriptions","monthly plan","six-month plan"],
  administration: ["single master account","normal moderation access","view-once media excluded"]
};
JS

echo "CHATSHARE REMAINING FOUNDATION CREATED — NO BUILD RUN"

create table if not exists public.blocks(id uuid primary key default gen_random_uuid(),blocker_id uuid not null references auth.users(id) on delete cascade,blocked_id uuid not null references auth.users(id) on delete cascade,created_at timestamptz default now(),unique(blocker_id,blocked_id));
alter table public.blocks enable row level security;
create policy "block own" on public.blocks for all using(auth.uid()=blocker_id) with check(auth.uid()=blocker_id);
alter table public.notifications add column if not exists actor_id uuid references auth.users(id);

create table if not exists public.blocks(id uuid primary key default gen_random_uuid(),blocker_id uuid references auth.users(id) on delete cascade,blocked_id uuid references auth.users(id) on delete cascade,created_at timestamptz default now(),unique(blocker_id,blocked_id));
create table if not exists public.call_logs(id uuid primary key default gen_random_uuid(),caller_id uuid references auth.users(id),receiver_id uuid references auth.users(id),call_type text check(call_type in('voice','video')),status text default 'ended',started_at timestamptz default now(),ended_at timestamptz);
create table if not exists public.message_media(id uuid primary key default gen_random_uuid(),message_id uuid references public.messages(id) on delete cascade,media_url text not null,media_type text,view_once boolean default false,expires_at timestamptz);
create table if not exists public.story_views(id uuid primary key default gen_random_uuid(),story_id uuid references public.stories(id) on delete cascade,viewer_id uuid references auth.users(id) on delete cascade,viewed_at timestamptz default now(),unique(story_id,viewer_id));
create table if not exists public.story_reactions(id uuid primary key default gen_random_uuid(),story_id uuid references public.stories(id) on delete cascade,user_id uuid references auth.users(id) on delete cascade,reaction text,created_at timestamptz default now(),unique(story_id,user_id));
create table if not exists public.user_settings(user_id uuid primary key references auth.users(id) on delete cascade,private_account boolean default false,online_status boolean default true,last_seen boolean default true,read_receipts boolean default true,typing_indicator boolean default true,push_notifications boolean default true,updated_at timestamptz default now());
create index if not exists idx_messages_conversation on public.messages(conversation_id,created_at);
create index if not exists idx_follows_following on public.follows(following_id);
create index if not exists idx_follows_follower on public.follows(follower_id);
create index if not exists idx_story_views_story on public.story_views(story_id);
create index if not exists idx_call_logs_users on public.call_logs(caller_id,receiver_id,started_at);
alter table public.message_media enable row level security;
alter table public.story_views enable row level security;
alter table public.story_reactions enable row level security;
alter table public.user_settings enable row level security;
alter table public.call_logs enable row level security;
do $$ begin
if not exists(select 1 from pg_policies where policyname='message media access' and tablename='message_media') then create policy "message media access" on public.message_media for all using(auth.uid() in(select sender_id from public.messages where id=message_id)); end if;
if not exists(select 1 from pg_policies where policyname='own story views' and tablename='story_views') then create policy "own story views" on public.story_views for all using(auth.uid()=viewer_id); end if;
if not exists(select 1 from pg_policies where policyname='own story reactions' and tablename='story_reactions') then create policy "own story reactions" on public.story_reactions for all using(auth.uid()=user_id); end if;
if not exists(select 1 from pg_policies where policyname='own settings' and tablename='user_settings') then create policy "own settings" on public.user_settings for all using(auth.uid()=user_id) with check(auth.uid()=user_id); end if;
if not exists(select 1 from pg_policies where policyname='own calls' and tablename='call_logs') then create policy "own calls" on public.call_logs for all using(auth.uid()=caller_id or auth.uid()=receiver_id); end if;
end $$;
