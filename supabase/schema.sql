-- MathTex THPT: schema khởi tạo cho Supabase PostgreSQL
-- Chạy toàn bộ file này trong Supabase SQL Editor của một project mới.
create extension if not exists pgcrypto;

create table if not exists public.classes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  code varchar(3) not null check (code ~ '^[0-9]{3}$'),
  name text not null,
  grade int not null check (grade between 10 and 12),
  school_year text,
  created_at timestamptz not null default now(),
  unique(owner_id, code),
  unique(id, owner_id)
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  class_id uuid not null,
  student_code varchar(6) not null check (student_code ~ '^[0-9]{6}$'),
  full_name text not null,
  order_no int not null check (order_no between 1 and 999),
  created_at timestamptz not null default now(),
  constraint students_class_owner_fk foreign key (class_id, owner_id)
    references public.classes(id, owner_id) on delete cascade,
  unique(class_id, student_code),
  unique(id, class_id)
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid(),
  class_id uuid not null,
  title text not null,
  exam_title text not null,
  exam_path text not null,
  assignment_code varchar(12) not null unique check (assignment_code ~ '^[A-Z0-9]{4,12}$'),
  opens_at timestamptz not null,
  closes_at timestamptz not null,
  duration_minutes int not null check (duration_minutes between 1 and 300),
  attempt_limit int not null default 1 check (attempt_limit between 1 and 10),
  created_at timestamptz not null default now(),
  constraint assignments_class_owner_fk foreign key (class_id, owner_id)
    references public.classes(id, owner_id) on delete cascade,
  check (closes_at > opens_at),
  unique(id, class_id)
);

create table if not exists public.attempts (
  id uuid primary key default gen_random_uuid(),
  attempt_token uuid not null unique default gen_random_uuid(),
  assignment_id uuid not null,
  student_id uuid not null,
  class_id uuid not null,
  student_code varchar(6) not null,
  student_name text not null,
  status text not null default 'started' check (status in ('started','submitted','expired')),
  answers jsonb not null default '{}'::jsonb,
  score numeric(5,2),
  started_at timestamptz not null default now(),
  submitted_at timestamptz,
  created_at timestamptz not null default now(),
  constraint attempts_assignment_class_fk foreign key (assignment_id, class_id)
    references public.assignments(id, class_id) on delete cascade,
  constraint attempts_student_class_fk foreign key (student_id, class_id)
    references public.students(id, class_id) on delete cascade
);

create index if not exists attempts_assignment_idx on public.attempts(assignment_id);
create index if not exists students_class_idx on public.students(class_id);
create unique index if not exists attempts_one_active_per_student
  on public.attempts(assignment_id, student_id) where status = 'started';

alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.assignments enable row level security;
alter table public.attempts enable row level security;

drop policy if exists "teacher manages own classes" on public.classes;
create policy "teacher manages own classes" on public.classes
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "teacher manages own students" on public.students;
create policy "teacher manages own students" on public.students
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "teacher manages own assignments" on public.assignments;
create policy "teacher manages own assignments" on public.assignments
  for all to authenticated using (owner_id = auth.uid()) with check (owner_id = auth.uid());
drop policy if exists "teacher reads own attempts" on public.attempts;
create policy "teacher reads own attempts" on public.attempts
  for select to authenticated using (
    exists (select 1 from public.assignments a
            where a.id = assignment_id and a.owner_id = auth.uid())
  );

-- Học sinh chỉ gọi RPC; không được đọc trực tiếp danh sách lớp/học sinh/đáp án.
create or replace function public.student_start_attempt(
  p_assignment_code text,
  p_student_code text
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  a public.assignments%rowtype;
  s public.students%rowtype;
  existing public.attempts%rowtype;
  new_attempt public.attempts%rowtype;
begin
  if coalesce(p_student_code, '') !~ '^[0-9]{6}$' then
    return jsonb_build_object('ok', false, 'message', 'Mã học sinh phải gồm 6 chữ số.');
  end if;

  select * into a from public.assignments
   where assignment_code = upper(trim(coalesce(p_assignment_code, '')))
   for update;
  if not found then
    return jsonb_build_object('ok', false, 'message', 'Mã giao đề không hợp lệ.');
  end if;
  if now() < a.opens_at then
    return jsonb_build_object('ok', false, 'message', 'Bài kiểm tra chưa mở.');
  end if;
  if now() > a.closes_at then
    return jsonb_build_object('ok', false, 'message', 'Bài kiểm tra đã đóng.');
  end if;

  select * into s from public.students
   where student_code = p_student_code and class_id = a.class_id;
  if not found then
    return jsonb_build_object('ok', false, 'message', 'Mã học sinh không thuộc lớp được giao đề.');
  end if;

  select * into existing from public.attempts
   where assignment_id = a.id and student_id = s.id and status = 'started'
   order by created_at desc limit 1;
  if found then
    new_attempt := existing;
  else
    if (select count(*) from public.attempts
        where assignment_id = a.id and student_id = s.id) >= a.attempt_limit then
      return jsonb_build_object('ok', false, 'message', 'Học sinh đã sử dụng hết số lần làm bài.');
    end if;
    insert into public.attempts(assignment_id, student_id, class_id, student_code, student_name)
    values (a.id, s.id, a.class_id, s.student_code, s.full_name)
    returning * into new_attempt;
  end if;

  return jsonb_build_object(
    'ok', true,
    'attempt_token', new_attempt.attempt_token,
    'student_code', s.student_code,
    'student_name', s.full_name,
    'assignment_title', a.title,
    'exam_title', a.exam_title,
    'exam_path', a.exam_path,
    'duration_minutes', a.duration_minutes,
    'started_at', new_attempt.started_at,
    'closes_at', a.closes_at,
    'answers', new_attempt.answers
  );
exception when unique_violation then
  select * into new_attempt from public.attempts
   where assignment_id = a.id and student_id = s.id and status = 'started'
   order by created_at desc limit 1;
  if found then
    return jsonb_build_object(
      'ok', true, 'attempt_token', new_attempt.attempt_token,
      'student_code', s.student_code, 'student_name', s.full_name,
      'assignment_title', a.title, 'exam_title', a.exam_title,
      'exam_path', a.exam_path, 'duration_minutes', a.duration_minutes,
      'started_at', new_attempt.started_at, 'closes_at', a.closes_at,
      'answers', new_attempt.answers
    );
  end if;
  return jsonb_build_object('ok', false, 'message', 'Không thể tạo lượt làm bài. Vui lòng thử lại.');
end;
$$;

create or replace function public.student_save_attempt(
  p_attempt_token uuid,
  p_answers jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  att public.attempts%rowtype;
  deadline timestamptz;
begin
  select * into att from public.attempts
   where attempt_token = p_attempt_token and status = 'started' for update;
  if not found then
    return jsonb_build_object('ok', false, 'message', 'Lượt làm bài không còn hoạt động.');
  end if;
  if jsonb_typeof(coalesce(p_answers, '{}'::jsonb)) <> 'object' then
    return jsonb_build_object('ok', false, 'message', 'Dữ liệu câu trả lời không hợp lệ.');
  end if;
  select least(asg.closes_at, att.started_at + make_interval(mins => asg.duration_minutes))
    into deadline from public.assignments asg where asg.id = att.assignment_id;
  if now() > deadline then
    update public.attempts set status = 'expired', answers = coalesce(p_answers, '{}'::jsonb), submitted_at = now()
     where id = att.id;
    return jsonb_build_object('ok', false, 'message', 'Bài đã hết giờ.');
  end if;
  update public.attempts set answers = coalesce(p_answers, '{}'::jsonb) where id = att.id;
  return jsonb_build_object('ok', true, 'message', 'Đã lưu câu trả lời.');
end;
$$;

create or replace function public.student_submit_attempt(
  p_attempt_token uuid,
  p_answers jsonb default '{}'::jsonb
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  att public.attempts%rowtype;
  deadline timestamptz;
begin
  select * into att from public.attempts
   where attempt_token = p_attempt_token for update;
  if not found then
    return jsonb_build_object('ok', false, 'message', 'Không tìm thấy lượt làm bài.');
  end if;
  if att.status = 'submitted' then
    return jsonb_build_object('ok', true, 'status', 'submitted', 'message', 'Bài đã được nộp trước đó.');
  elsif att.status = 'expired' then
    return jsonb_build_object('ok', true, 'status', 'expired', 'message', 'Bài đã hết giờ.');
  end if;
  if jsonb_typeof(coalesce(p_answers, '{}'::jsonb)) <> 'object' then
    return jsonb_build_object('ok', false, 'message', 'Dữ liệu câu trả lời không hợp lệ.');
  end if;

  select least(asg.closes_at, att.started_at + make_interval(mins => asg.duration_minutes))
    into deadline from public.assignments asg where asg.id = att.assignment_id;
  if now() > deadline then
    update public.attempts set status = 'expired', answers = coalesce(p_answers, '{}'::jsonb), submitted_at = now()
     where id = att.id;
    return jsonb_build_object('ok', true, 'status', 'expired', 'message', 'Đã hết giờ; hệ thống đã ghi nhận bài.');
  end if;

  update public.attempts set status = 'submitted', answers = coalesce(p_answers, '{}'::jsonb), submitted_at = now()
   where id = att.id;
  return jsonb_build_object('ok', true, 'status', 'submitted', 'message', 'Đã ghi nhận bài nộp.');
end;
$$;

revoke all on function public.student_start_attempt(text, text) from public;
revoke all on function public.student_submit_attempt(uuid, jsonb) from public;
revoke all on function public.student_save_attempt(uuid, jsonb) from public;
grant execute on function public.student_start_attempt(text, text) to anon, authenticated;
grant execute on function public.student_submit_attempt(uuid, jsonb) to anon, authenticated;
grant execute on function public.student_save_attempt(uuid, jsonb) to anon, authenticated;
