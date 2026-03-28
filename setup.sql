-- VibeKids Supabase Schema
-- Run this in your Supabase SQL editor

-- Profiles table (extends auth.users)
create table if not exists profiles (
  id uuid references auth.users on delete cascade primary key,
  first_name text default '',
  last_name text default '',
  avatar_url text default '',
  created_at timestamp with time zone default now()
);

-- Apps/links shared by community
create table if not exists apps (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text default '',
  url text not null,
  image_url text default '',
  creator_id uuid references profiles(id) on delete cascade not null,
  created_at timestamp with time zone default now()
);

-- Prompts shared by community
create table if not exists prompts (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  content text not null,
  creator_id uuid references profiles(id) on delete cascade not null,
  created_at timestamp with time zone default now()
);

-- Enable RLS
alter table profiles enable row level security;
alter table apps enable row level security;
alter table prompts enable row level security;

-- Profiles policies
create policy "Public profiles are viewable by everyone" on profiles for select using (true);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on profiles for insert with check (auth.uid() = id);

-- Apps policies
create policy "Apps are viewable by everyone" on apps for select using (true);
create policy "Users can create apps" on apps for insert with check (auth.uid() = creator_id);
create policy "Users can update own apps" on apps for update using (auth.uid() = creator_id);
create policy "Users can delete own apps" on apps for delete using (auth.uid() = creator_id);

-- Prompts policies
create policy "Prompts are viewable by everyone" on prompts for select using (true);
create policy "Users can create prompts" on prompts for insert with check (auth.uid() = creator_id);
create policy "Users can update own prompts" on prompts for update using (auth.uid() = creator_id);
create policy "Users can delete own prompts" on prompts for delete using (auth.uid() = creator_id);

-- Auto-create profile on signup
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, first_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'name', 'משתמש'),
    coalesce(new.raw_user_meta_data->>'avatar_url', new.raw_user_meta_data->>'picture', '')
  );
  return new;
end;
$$ language plpgsql security definer;

-- Drop trigger if exists then create
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
