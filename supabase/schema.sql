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
create policy notifications_select on notifications for select to authenticated using (auth.uid() = user_id = auth.uid());

drop policy if exists notifications_update on notifications;
create policy notifications_update on notifications for update to authenticated using (auth.uid() = user_id = auth.uid());

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

