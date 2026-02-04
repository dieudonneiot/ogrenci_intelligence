-- RLS policies for chat and chatbot tables

alter table public.chat_sessions enable row level security;

drop policy if exists chat_sessions_select_own on public.chat_sessions;
create policy chat_sessions_select_own
on public.chat_sessions
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists chat_sessions_insert_own on public.chat_sessions;
create policy chat_sessions_insert_own
on public.chat_sessions
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists chat_sessions_update_own on public.chat_sessions;
create policy chat_sessions_update_own
on public.chat_sessions
for update
to authenticated
using (user_id = auth.uid() or is_admin())
with check (user_id = auth.uid() or is_admin());

drop policy if exists chat_sessions_delete_own on public.chat_sessions;
create policy chat_sessions_delete_own
on public.chat_sessions
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

alter table public.chat_messages enable row level security;

drop policy if exists chat_messages_select_own on public.chat_messages;
create policy chat_messages_select_own
on public.chat_messages
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists chat_messages_insert_own on public.chat_messages;
create policy chat_messages_insert_own
on public.chat_messages
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists chat_messages_delete_own on public.chat_messages;
create policy chat_messages_delete_own
on public.chat_messages
for delete
to authenticated
using (user_id = auth.uid() or is_admin());

alter table public.chatbot_faqs enable row level security;

drop policy if exists chatbot_faqs_select_authenticated on public.chatbot_faqs;
create policy chatbot_faqs_select_authenticated
on public.chatbot_faqs
for select
to anon, authenticated
using (is_active = true);

drop policy if exists chatbot_faqs_select_admin on public.chatbot_faqs;
create policy chatbot_faqs_select_admin
on public.chatbot_faqs
for select
to authenticated
using (is_admin());

drop policy if exists chatbot_faqs_insert_admin on public.chatbot_faqs;
create policy chatbot_faqs_insert_admin
on public.chatbot_faqs
for insert
to authenticated
with check (is_admin());

drop policy if exists chatbot_faqs_update_admin on public.chatbot_faqs;
create policy chatbot_faqs_update_admin
on public.chatbot_faqs
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists chatbot_faqs_delete_admin on public.chatbot_faqs;
create policy chatbot_faqs_delete_admin
on public.chatbot_faqs
for delete
to authenticated
using (is_admin());

alter table public.chatbot_feedback enable row level security;

drop policy if exists chatbot_feedback_select_own on public.chatbot_feedback;
create policy chatbot_feedback_select_own
on public.chatbot_feedback
for select
to authenticated
using (user_id = auth.uid() or is_admin());

drop policy if exists chatbot_feedback_insert_own on public.chatbot_feedback;
create policy chatbot_feedback_insert_own
on public.chatbot_feedback
for insert
to authenticated
with check (user_id = auth.uid() or is_admin());

drop policy if exists chatbot_feedback_delete_own on public.chatbot_feedback;
create policy chatbot_feedback_delete_own
on public.chatbot_feedback
for delete
to authenticated
using (user_id = auth.uid() or is_admin());
