-- Nano-Learning mini-quiz (Reels-style) support
--
-- Adds quiz questions for courses and a safe RPC-based submission flow that:
-- - validates answers server-side
-- - prevents awarding points more than once per course
-- - logs points via add_activity_and_points()

-- --------------------------
-- Tables
-- --------------------------

create table if not exists public.course_quiz_questions (
  id uuid primary key default gen_random_uuid(),
  course_id uuid not null references public.courses(id) on delete cascade,
  question text not null,
  options text[] not null,
  correct_index integer not null,
  is_active boolean not null default true,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

create table if not exists public.course_quiz_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  course_id uuid not null references public.courses(id) on delete cascade,
  question_id uuid references public.course_quiz_questions(id) on delete set null,
  selected_index integer not null,
  is_correct boolean not null default false,
  points_awarded integer not null default 0,
  created_at timestamp with time zone not null default timezone('utc'::text, now())
);

-- Award at most once per user/course
create unique index if not exists uq_course_quiz_award_once
on public.course_quiz_attempts(user_id, course_id)
where points_awarded > 0;

-- --------------------------
-- RLS
-- --------------------------

alter table public.course_quiz_questions enable row level security;
alter table public.course_quiz_attempts enable row level security;

drop policy if exists course_quiz_questions_select_admin on public.course_quiz_questions;
create policy course_quiz_questions_select_admin
on public.course_quiz_questions
for select
to authenticated
using (is_admin());

drop policy if exists course_quiz_questions_insert_admin on public.course_quiz_questions;
create policy course_quiz_questions_insert_admin
on public.course_quiz_questions
for insert
to authenticated
with check (is_admin());

drop policy if exists course_quiz_questions_update_admin on public.course_quiz_questions;
create policy course_quiz_questions_update_admin
on public.course_quiz_questions
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists course_quiz_questions_delete_admin on public.course_quiz_questions;
create policy course_quiz_questions_delete_admin
on public.course_quiz_questions
for delete
to authenticated
using (is_admin());

drop policy if exists course_quiz_attempts_select_own on public.course_quiz_attempts;
create policy course_quiz_attempts_select_own
on public.course_quiz_attempts
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists course_quiz_attempts_insert_own on public.course_quiz_attempts;
create policy course_quiz_attempts_insert_own
on public.course_quiz_attempts
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

-- --------------------------
-- RPCs
-- --------------------------

-- Returns the active quiz question for a course WITHOUT the correct answer.
create or replace function public.get_course_quiz_question(
  p_course_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_q record;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_course_id is null then
    raise exception 'Course id is required';
  end if;

  select q.id, q.question, q.options
    into v_q
  from public.course_quiz_questions q
  where q.course_id = p_course_id
    and q.is_active = true
  order by q.created_at desc
  limit 1;

  if v_q.id is null then
    return null;
  end if;

  return jsonb_build_object(
    'question_id', v_q.id,
    'question', v_q.question,
    'options', v_q.options
  );
end;
$$;

grant execute on function public.get_course_quiz_question(uuid) to authenticated;

-- Validates a quiz attempt server-side and awards points once per course.
create or replace function public.submit_course_quiz_attempt(
  p_course_id uuid,
  p_question_id uuid,
  p_selected_index integer,
  p_points integer default 10
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_correct integer;
  v_is_correct boolean;
  v_award integer := 0;
  v_already_awarded boolean := false;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  if p_course_id is null or p_question_id is null then
    raise exception 'Course and question are required';
  end if;

  select q.correct_index
    into v_correct
  from public.course_quiz_questions q
  where q.id = p_question_id
    and q.course_id = p_course_id
    and q.is_active = true
  limit 1;

  if v_correct is null then
    raise exception 'Quiz question not found';
  end if;

  v_is_correct := (p_selected_index = v_correct);

  select exists (
    select 1
    from public.course_quiz_attempts a
    where a.user_id = v_uid
      and a.course_id = p_course_id
      and a.points_awarded > 0
  ) into v_already_awarded;

  if v_is_correct and not v_already_awarded then
    v_award := greatest(coalesce(p_points, 0), 0);
  end if;

  insert into public.course_quiz_attempts (
    user_id,
    course_id,
    question_id,
    selected_index,
    is_correct,
    points_awarded
  ) values (
    v_uid,
    p_course_id,
    p_question_id,
    p_selected_index,
    v_is_correct,
    v_award
  );

  if v_award > 0 then
    perform public.add_activity_and_points(
      v_uid,
      'course',
      'nano_quiz',
      v_award,
      'Nano-learning mini-quiz',
      jsonb_build_object('course_id', p_course_id, 'question_id', p_question_id)
    );
  end if;

  return jsonb_build_object(
    'is_correct', v_is_correct,
    'points_awarded', v_award
  );
end;
$$;

grant execute on function public.submit_course_quiz_attempt(uuid, uuid, integer, integer) to authenticated;

