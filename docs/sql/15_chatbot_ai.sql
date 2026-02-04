-- Chatbot AI groundwork
-- Run in Supabase SQL editor

-- 1) Link messages to sessions + store metadata
alter table public.chat_messages
  add column if not exists session_id uuid;

alter table public.chat_messages
  add column if not exists metadata jsonb default '{}'::jsonb;

-- 2) Session helpers
alter table public.chat_sessions
  add column if not exists last_message_at timestamp without time zone;

alter table public.chat_sessions
  add column if not exists title text;

-- 3) FK (safe add)
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'chat_messages_session_id_fkey'
  ) then
    alter table public.chat_messages
      add constraint chat_messages_session_id_fkey
      foreign key (session_id)
      references public.chat_sessions(id)
      on delete set null;
  end if;
end $$;

-- 4) Indexes
create index if not exists chat_messages_user_created_idx
  on public.chat_messages(user_id, created_at);

create index if not exists chat_messages_session_created_idx
  on public.chat_messages(session_id, created_at);

-- NOTE: Postgres requires IMMUTABLE expressions for expression indexes.
-- `to_tsvector()` is not IMMUTABLE, so we store a materialized tsvector column
-- and index that column instead.

alter table public.chatbot_faqs
  add column if not exists search_vector tsvector;

create or replace function public.chatbot_faqs_set_search_vector()
returns trigger
language plpgsql
as $$
begin
  new.search_vector :=
    to_tsvector(
      'simple',
      coalesce(new.question, '') || ' ' ||
      coalesce(new.answer, '') || ' ' ||
      coalesce(array_to_string(new.keywords, ' '), '')
    );
  return new;
end;
$$;

drop trigger if exists chatbot_faqs_search_vector_trg on public.chatbot_faqs;
create trigger chatbot_faqs_search_vector_trg
  before insert or update on public.chatbot_faqs
  for each row
  execute function public.chatbot_faqs_set_search_vector();

update public.chatbot_faqs
set search_vector =
  to_tsvector(
    'simple',
    coalesce(question, '') || ' ' ||
    coalesce(answer, '') || ' ' ||
    coalesce(array_to_string(keywords, ' '), '')
  )
where search_vector is null;

create index if not exists chatbot_faqs_search_idx
  on public.chatbot_faqs
  using gin (search_vector);

-- 5) Auto-update session counters on new messages
create or replace function public.bump_chat_session()
returns trigger
language plpgsql
as $$
begin
  if new.session_id is not null then
    update public.chat_sessions
      set message_count = coalesce(message_count, 0) + 1,
          last_message_at = now()
      where id = new.session_id;
  end if;
  return new;
end;
$$;

drop trigger if exists chat_messages_bump_session on public.chat_messages;
create trigger chat_messages_bump_session
  after insert on public.chat_messages
  for each row
  execute function public.bump_chat_session();

-- 6) Optional: seed FAQs from React (ASCII text)
insert into public.chatbot_faqs (category, question, answer, keywords, is_active)
values
  (
    'staj',
    'Staj basvurusu nasil yapilir?',
    E'Staj basvurusu yapmak icin oneriler:\\n\\n1. Profilini tamamla\\n2. Staj ilanlarini incele\\n3. Guncel bir CV hazirla\\n4. Ilan detayindan basvuru yap\\n\\nIpuclari: Her basvuru icin kisa bir on yazi hazirlaman faydali olur.',
    ARRAY['staj','basvuru','nasil','basvurabilirim'],
    true
  ),
  (
    'cv',
    'CV hazirlama icin ipuclari verir misin?',
    E'Etkili bir CV icin oneriler:\\n\\n- 1-2 sayfa ve sade tasarim\\n- Guncel iletisim bilgileri\\n- Ozet / hedef bolumu\\n- Egitim, deneyim, projeler\\n- Beceriler ve sertifikalar\\n\\nIpuclari: Basvuruya gore CV\'ni ozellestir.',
    ARRAY['cv','ozgecmis','resume','hazirlama'],
    true
  ),
  (
    'mulakat',
    'Mulakat icin hazirlik nasil yapilir?',
    E'Mulakat oncesi hazirlik:\\n\\n- Sirketi arastir\\n- Pozisyonu analiz et\\n- STAR metodunu kullan\\n- Soru listesi hazirla\\n\\nMulakat gunu:\\n- Zamaninda gel\\n- Net ve guvenilir iletisim\\n- Orneklerle anlat',
    ARRAY['mulakat','interview','gorusme','ipucu'],
    true
  ),
  (
    'bolum',
    'Hangi bolumlerde icerik bulunuyor?',
    E'Platformdaki ana alanlar:\\n\\n- Muhendislik\\n- Isletme\\n- Tasarim\\n- Saglik\\n- Hukuk\\n\\nIstersen ilgilendigin bolumu yaz, sana ozel kaynaklar onereyim.',
    ARRAY['bolum','departman','alan','hangi'],
    true
  ),
  (
    'staj_sureci',
    'Staj sureci ve asamalari nelerdir?',
    E'Tipik staj sureci:\\n\\n1. Basvuru (1-2 hafta)\\n2. On degerlendirme (3-5 gun)\\n3. Mulakat (1-2 hafta)\\n4. Sonuc (3-7 gun)\\n\\nStaj sureleri:\\n- Kisa donem: 20-30 is gunu\\n- Uzun donem: 40-60 is gunu\\n- Part-time: haftada 2-3 gun',
    ARRAY['staj','surec','asama','ne kadar'],
    true
  );
