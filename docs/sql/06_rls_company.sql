-- RLS policies for company-related tables

alter table public.companies enable row level security;

drop policy if exists companies_select_approved on public.companies;
create policy companies_select_approved
on public.companies
for select
to authenticated
using (approval_status = 'approved' and banned_at is null);

drop policy if exists companies_select_member on public.companies;
create policy companies_select_member
on public.companies
for select
to authenticated
using (is_company_member(id) or is_admin());

drop policy if exists companies_insert_admin on public.companies;
create policy companies_insert_admin
on public.companies
for insert
to authenticated
with check (is_admin());

drop policy if exists companies_update_company on public.companies;
create policy companies_update_company
on public.companies
for update
to authenticated
using (is_company_staff(id) or is_admin())
with check (is_company_staff(id) or is_admin());

drop policy if exists companies_delete_admin on public.companies;
create policy companies_delete_admin
on public.companies
for delete
to authenticated
using (is_admin());

alter table public.company_users enable row level security;

drop policy if exists company_users_select_scope on public.company_users;
create policy company_users_select_scope
on public.company_users
for select
to authenticated
using (
  user_id = auth.uid()
  or is_company_staff(company_id)
  or is_admin()
);

drop policy if exists company_users_insert_staff on public.company_users;
create policy company_users_insert_staff
on public.company_users
for insert
to authenticated
with check (is_company_staff(company_id) or is_admin());

drop policy if exists company_users_update_staff on public.company_users;
create policy company_users_update_staff
on public.company_users
for update
to authenticated
using (is_company_staff(company_id) or is_admin())
with check (is_company_staff(company_id) or is_admin());

drop policy if exists company_users_delete_staff on public.company_users;
create policy company_users_delete_staff
on public.company_users
for delete
to authenticated
using (is_company_staff(company_id) or is_admin());

alter table public.company_metrics enable row level security;

drop policy if exists company_metrics_select_company on public.company_metrics;
create policy company_metrics_select_company
on public.company_metrics
for select
to authenticated
using (is_company_staff(company_id) or is_admin());

drop policy if exists company_metrics_insert_admin on public.company_metrics;
create policy company_metrics_insert_admin
on public.company_metrics
for insert
to authenticated
with check (is_admin());

drop policy if exists company_metrics_update_admin on public.company_metrics;
create policy company_metrics_update_admin
on public.company_metrics
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists company_metrics_delete_admin on public.company_metrics;
create policy company_metrics_delete_admin
on public.company_metrics
for delete
to authenticated
using (is_admin());

alter table public.company_subscriptions enable row level security;

drop policy if exists company_subscriptions_select_company on public.company_subscriptions;
create policy company_subscriptions_select_company
on public.company_subscriptions
for select
to authenticated
using (is_company_member(company_id) or is_admin());

drop policy if exists company_subscriptions_insert_admin on public.company_subscriptions;
create policy company_subscriptions_insert_admin
on public.company_subscriptions
for insert
to authenticated
with check (is_admin());

drop policy if exists company_subscriptions_update_admin on public.company_subscriptions;
create policy company_subscriptions_update_admin
on public.company_subscriptions
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists company_subscriptions_delete_admin on public.company_subscriptions;
create policy company_subscriptions_delete_admin
on public.company_subscriptions
for delete
to authenticated
using (is_admin());

alter table public.subscription_plans enable row level security;

drop policy if exists subscription_plans_select_authenticated on public.subscription_plans;
create policy subscription_plans_select_authenticated
on public.subscription_plans
for select
to authenticated
using (true);

drop policy if exists subscription_plans_insert_admin on public.subscription_plans;
create policy subscription_plans_insert_admin
on public.subscription_plans
for insert
to authenticated
with check (is_admin());

drop policy if exists subscription_plans_update_admin on public.subscription_plans;
create policy subscription_plans_update_admin
on public.subscription_plans
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists subscription_plans_delete_admin on public.subscription_plans;
create policy subscription_plans_delete_admin
on public.subscription_plans
for delete
to authenticated
using (is_admin());

alter table public.job_templates enable row level security;

drop policy if exists job_templates_select_company on public.job_templates;
create policy job_templates_select_company
on public.job_templates
for select
to authenticated
using (is_company_staff(company_id) or is_admin());

drop policy if exists job_templates_insert_company on public.job_templates;
create policy job_templates_insert_company
on public.job_templates
for insert
to authenticated
with check ((is_company_staff(company_id) and created_by = auth.uid()) or is_admin());

drop policy if exists job_templates_update_company on public.job_templates;
create policy job_templates_update_company
on public.job_templates
for update
to authenticated
using (is_company_staff(company_id) or is_admin())
with check (is_company_staff(company_id) or is_admin());

drop policy if exists job_templates_delete_company on public.job_templates;
create policy job_templates_delete_company
on public.job_templates
for delete
to authenticated
using (is_company_staff(company_id) or is_admin());

alter table public.payments enable row level security;

drop policy if exists payments_select_company on public.payments;
create policy payments_select_company
on public.payments
for select
to authenticated
using (is_company_member(company_id) or is_admin());

drop policy if exists payments_insert_admin on public.payments;
create policy payments_insert_admin
on public.payments
for insert
to authenticated
with check (is_admin());

drop policy if exists payments_update_admin on public.payments;
create policy payments_update_admin
on public.payments
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists payments_delete_admin on public.payments;
create policy payments_delete_admin
on public.payments
for delete
to authenticated
using (is_admin());

alter table public.report_cache enable row level security;

drop policy if exists report_cache_select_company on public.report_cache;
create policy report_cache_select_company
on public.report_cache
for select
to authenticated
using (is_company_staff(company_id) or is_admin());

drop policy if exists report_cache_insert_admin on public.report_cache;
create policy report_cache_insert_admin
on public.report_cache
for insert
to authenticated
with check (is_admin());

drop policy if exists report_cache_update_admin on public.report_cache;
create policy report_cache_update_admin
on public.report_cache
for update
to authenticated
using (is_admin())
with check (is_admin());

drop policy if exists report_cache_delete_admin on public.report_cache;
create policy report_cache_delete_admin
on public.report_cache
for delete
to authenticated
using (is_admin());
