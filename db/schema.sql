-- Postop WhatsApp (Anicura Lleida) — esquema Supabase/Postgres
-- Reconstruido a partir de la API en vivo (PostgREST /rest/v1/ OpenAPI) + pruebas.
-- No es el DDL original exacto; ajusta tipos/constraints a tu instalación real.

create extension if not exists "uuid-ossp";

-- =========================================================================
-- follow_ups : un paciente dado de alta (creado por el workflow "Activación")
-- =========================================================================
create table if not exists public.follow_ups (
  id                      uuid primary key default uuid_generate_v4(),
  provet_consultation_id  bigint,
  provet_patient_id       bigint,
  provet_client_id        bigint,
  patient_name            text,
  species                 text,
  breed                   text,
  weight_kg               numeric,
  owner_name              text,
  owner_phone             text,           -- SIEMPRE normalizado a +E.164 (ver normalizePhone)
  owner_language          text default 'es',
  surgery_type_raw        text,
  surgery_date            timestamptz,
  discharge_date          timestamptz,
  discharge_instructions  text,
  medications             text,           -- JSON serializado: [{name,dose,frequency,instructions}]
  vet_name                text,
  total_check_in_days     int  default 7,
  check_ins_per_day       int  default 1,
  current_day             int  default 0,
  status                  text default 'active',   -- 'active' | ...
  last_risk_level         text default 'green',
  yellow_count            int  default 0,
  red_count               int  default 0,
  created_at              timestamptz default now(),
  updated_at              timestamptz default now()
);

-- =========================================================================
-- check_ins : una sesión de seguimiento (día N) para un follow_up
-- =========================================================================
create table if not exists public.check_ins (
  id                    uuid primary key default uuid_generate_v4(),
  follow_up_id          uuid references public.follow_ups(id),
  day_number            int,
  risk_level            text default 'green',   -- 'green' | 'yellow' | 'red'
  risk_summary          text,                   -- OJO: la columna de resumen es risk_summary (no 'summary')
  symptoms              jsonb default '[]'::jsonb,
  medication_adherence  boolean,
  status                text default 'pending', -- 'pending' | 'in_progress' | 'completed'
  started_at            timestamptz,
  completed_at          timestamptz,
  system_prompt_version text,
  created_at            timestamptz default now()
);

-- =========================================================================
-- messages : cada mensaje de la conversación de WhatsApp
-- =========================================================================
create table if not exists public.messages (
  id            uuid primary key default uuid_generate_v4(),
  check_in_id   uuid not null references public.check_ins(id),
  direction     text not null check (direction in ('inbound','outbound')),
  -- valores verificados aceptados: 'owner' (propietario) y 'system' (asistente/bot).
  -- El workflow lee sender <> 'owner' como rol 'assistant'.
  sender        text not null check (sender in ('owner','system')),
  content       text not null,
  wa_message_id text,
  wa_timestamp  timestamptz,
  message_type  text default 'text',
  created_at    timestamptz default now()
);

create index if not exists idx_follow_ups_owner_phone_status on public.follow_ups (owner_phone, status);
create index if not exists idx_check_ins_followup_status      on public.check_ins (follow_up_id, status);
create index if not exists idx_messages_check_in              on public.messages (check_in_id, created_at);

-- Otras tablas presentes en el proyecto (no usadas directamente por estos workflows):
--   learned_procedures, alerts, hitl_feedback
