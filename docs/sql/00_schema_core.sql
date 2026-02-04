-- Core schema bootstrap for a NEW Supabase project (minimal fields used by the app)
--
-- Run this FIRST in Supabase SQL editor.
-- Then run the RLS/RPC scripts under docs/sql (see docs/sql/README_NEW_PROJECT.md).

-- Extensions (Supabase usually has these, but keep it safe)
create extension if not exists "pgcrypto";
create extension if not exists "uuid-ossp";

-- --------------------------
-- Users / Profiles / Notifs
-- --------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  email text,
  full_name text,
  avatar_url text,
  phone text,
  year integer,
  department text,
  total_points integer not null default 0,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.notification_preferences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  email_notifications boolean not null default true,
  new_course_notifications boolean not null default true,
  job_alerts boolean not null default true,
  newsletter boolean not null default false,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (user_id)
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  type text not null default 'info',
  is_read boolean not null default false,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

-- --------------------------
-- Admin
-- --------------------------
create table if not exists public.admins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  email text not null unique,
  role text not null default 'admin',
  permissions jsonb not null default '{}'::jsonb,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.admin_logs (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid references public.admins(id) on delete set null,
  action_type text not null,
  target_type text,
  target_id uuid,
  details jsonb not null default '{}'::jsonb,
  ip_address inet,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.admin_setup_logs (
  id uuid primary key default gen_random_uuid(),
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  ip_address inet,
  user_agent text,
  success boolean,
  email text,
  error_message text
);

-- --------------------------
-- Company
-- --------------------------
create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  logo_url text,
  email text,
  description text,
  sector text,
  city text,
  phone text,
  address text,
  website text,
  employee_count text,
  founded_year integer,
  linkedin text,
  twitter text,
  facebook text,
  instagram text,
  cover_image_url text,
  verified boolean not null default false,
  tax_number text unique,
  trade_registry_number text,
  approval_status text not null default 'pending',
  approved_at timestamp with time zone,
  approved_by uuid references public.admins(id) on delete set null,
  rejection_reason text,
  banned_at timestamp with time zone,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.company_users (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null default 'member',
  permissions jsonb not null default '{}'::jsonb,
  invited_by uuid references auth.users(id),
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (company_id, user_id)
);

create table if not exists public.company_subscriptions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  plan_type text not null default 'free',
  starts_at timestamp with time zone not null default timezone('utc'::text, now()),
  ends_at timestamp with time zone,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.company_metrics (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  metric_date date not null default current_date,
  total_views integer not null default 0,
  unique_visitors integer not null default 0,
  total_applications integer not null default 0,
  accepted_applications integer not null default 0,
  rejected_applications integer not null default 0,
  avg_response_time_hours numeric not null default 0,
  conversion_rate numeric not null default 0,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  plan_type text not null unique,
  name text not null,
  description text,
  price_usd numeric not null default 0,
  interval text not null default 'month',
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.job_templates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  title text not null,
  description text,
  requirements text[],
  responsibilities text[],
  benefits text,
  created_by uuid not null references auth.users(id) on delete cascade,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  plan_type text,
  amount_usd numeric not null default 0,
  status text not null default 'pending',
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.report_cache (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  cache_key text not null,
  payload jsonb not null default '{}'::jsonb,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (company_id, cache_key)
);

-- --------------------------
-- Courses
-- --------------------------
create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  department text,
  duration text,
  level text,
  instructor text,
  video_url text,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.course_enrollments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  enrolled_at timestamp with time zone not null default timezone('utc'::text, now()),
  progress integer not null default 0,
  unique (user_id, course_id)
);

create table if not exists public.completed_courses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  completed_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (user_id, course_id)
);

create table if not exists public.course_reviews (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null default 5 check (rating between 1 and 5),
  review text,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (course_id, user_id)
);

-- --------------------------
-- Jobs + Internships
-- --------------------------
create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete set null,
  company text,
  company_name text,
  title text not null,
  department text,
  location text,
  description text,
  requirements text,
  benefits text,
  contact_email text,
  salary text,
  salary_min integer,
  salary_max integer,
  type text,
  work_type text,
  is_remote boolean not null default false,
  is_active boolean not null default true,
  min_year integer,
  max_year integer,
  deadline timestamp with time zone,
  views_count integer not null default 0,
  application_count integer not null default 0,
  created_by uuid references auth.users(id),
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.internships (
  id uuid primary key default gen_random_uuid(),
  company_id uuid references public.companies(id) on delete set null,
  company_name text,
  title text not null,
  department text,
  location text,
  description text,
  requirements text,
  benefits text,
  is_remote boolean not null default false,
  is_active boolean not null default true,
  start_date date,
  end_date date,
  duration_months integer,
  quota integer not null default 1,
  deadline timestamp with time zone,
  is_paid boolean not null default false,
  monthly_stipend text,
  provides_certificate boolean not null default true,
  possibility_of_employment boolean not null default false,
  created_by uuid references auth.users(id),
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.job_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid not null references public.jobs(id) on delete cascade,
  cover_letter text,
  cv_url text,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  applied_at timestamp with time zone not null default timezone('utc'::text, now()),
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.internship_applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  internship_id uuid not null references public.internships(id) on delete cascade,
  motivation_letter text,
  cv_url text,
  status text not null default 'pending' check (status in ('pending','accepted','rejected')),
  applied_at timestamp with time zone not null default timezone('utc'::text, now()),
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.job_views (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  viewed_at timestamp with time zone not null default timezone('utc'::text, now()),
  ip_address inet,
  user_agent text,
  session_id text
);

create table if not exists public.internship_views (
  id uuid primary key default gen_random_uuid(),
  internship_id uuid not null references public.internships(id) on delete cascade,
  user_id uuid references auth.users(id) on delete set null,
  viewed_at timestamp with time zone not null default timezone('utc'::text, now()),
  ip_address inet,
  user_agent text,
  session_id text
);

-- --------------------------
-- Favorites
-- --------------------------
create table if not exists public.favorites (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null check (type in ('job','internship','course')),
  job_id uuid references public.jobs(id) on delete cascade,
  internship_id uuid references public.internships(id) on delete cascade,
  course_id uuid references public.courses(id) on delete cascade,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

-- --------------------------
-- Points / Badges
-- --------------------------
create table if not exists public.activity_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category text not null,
  action text not null,
  points integer not null,
  metadata jsonb,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.user_points (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  source text not null,
  description text,
  points integer not null,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.rewards (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text not null,
  required_points integer not null,
  department text,
  icon text,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.user_badges (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  badge_type text not null,
  badge_title text not null,
  badge_description text,
  icon text,
  earned_at timestamp with time zone not null default timezone('utc'::text, now()),
  points_awarded integer not null default 0
);

create table if not exists public.leaderboard_snapshots (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  department text,
  period_date date not null default current_date,
  rank_overall integer,
  rank_department integer,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

-- --------------------------
-- Chat
-- --------------------------
create table if not exists public.chat_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  started_at timestamp with time zone not null default timezone('utc'::text, now()),
  ended_at timestamp with time zone,
  message_count integer not null default 0,
  satisfaction_rating integer,
  feedback text
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  session_id uuid references public.chat_sessions(id) on delete set null,
  message text not null,
  type text not null check (type in ('user','bot')),
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.chatbot_faqs (
  id uuid primary key default gen_random_uuid(),
  category text not null,
  question text not null,
  answer text not null,
  keywords text[],
  view_count integer not null default 0,
  helpful_count integer not null default 0,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  updated_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.chatbot_feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  message_id uuid references public.chat_messages(id) on delete cascade,
  is_helpful boolean not null,
  feedback_text text,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

-- --------------------------
-- Other supporting tables (used by RLS scripts)
-- --------------------------
create table if not exists public.employer_ratings (
  id uuid primary key default gen_random_uuid(),
  employer_id uuid references auth.users(id) on delete set null,
  student_id uuid references auth.users(id) on delete cascade,
  internship_id uuid references public.internships(id) on delete set null,
  rating integer not null default 5 check (rating between 1 and 5),
  feedback text,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.intern_evaluations (
  id uuid primary key default gen_random_uuid(),
  internship_application_id uuid not null references public.internship_applications(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  performance_score integer not null default 0,
  attendance_score integer not null default 0,
  team_work_score integer not null default 0,
  technical_score integer not null default 0,
  final_rating integer not null default 0,
  would_hire_again boolean not null default false,
  comments text,
  evaluated_by uuid not null references auth.users(id) on delete set null,
  created_at timestamp with time zone not null default timezone('utc'::text, now()),
  unique (internship_application_id)
);

create table if not exists public.application_notes (
  id uuid primary key default gen_random_uuid(),
  application_id uuid not null,
  application_type text not null check (application_type in ('job','internship')),
  company_user_id uuid not null references public.company_users(id) on delete cascade,
  note text not null,
  is_private boolean not null default false,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);
