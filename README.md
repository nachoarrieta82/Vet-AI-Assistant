# Postop WhatsApp — Seguimiento postoperatorio veterinario 

Sistema de seguimiento postoperatorio por WhatsApp construido con **n8n + Supabase + Claude (Anthropic)**.
Un propietario cuya mascota ha sido operada recibe/mantiene una conversación de check-in por WhatsApp;
Claude (Haiku) conduce el protocolo diario, guarda todo en Supabase, detecta alertas y, al completar,
avisa al equipo de la clínica.

> ⚠️ **Repo público:** aquí NO hay credenciales. Todos los secretos se inyectan en n8n vía
> **Variables** (`$vars.*`) y **Credentials**. Los valores sensibles en los workflows están como
> placeholders (`YOUR_...`).

## Arquitectura

```
Provet (alta) ──POST /provet-discharge──►  Postop — Activación  ──►  tabla follow_ups
                                            (normaliza teléfono +E.164)

Móvil del dueño ──WhatsApp──► Meta ──POST /whatsapp-meta──►  Postop — WhatsApp Inbound (Meta)
                                                              (verify GET + normaliza + reenvía)
                                                                        │
                                                       POST /whatsapp-inbound {owner_phone, message}
                                                                        ▼
                                                              Postop — Conversación
   Get follow_up → find/create check_in → historial → Claude Haiku → parse → guarda en Supabase
   → responde al dueño por WhatsApp
   → (si [CHECK-IN:COMPLETO]) email SMTP a la clínica + WhatsApp de plantilla al equipo de guardia
```

## Workflows (`/workflows`)

| Archivo | Nombre en n8n | Endpoint | Función |
|---|---|---|---|
| `postop-activacion.json` | Postop — Activación | `POST /webhook/provet-discharge` | Alta de paciente desde Provet → crea `follow_ups` (normaliza teléfono) |
| `postop-whatsapp-inbound-meta.json` | Postop — WhatsApp Inbound (Meta) | `GET/POST /webhook/whatsapp-meta` | Callback de Meta: verificación + parseo/normalización del mensaje entrante → reenvía a Conversación |
| `postop-conversacion.json` | Postop — Conversación | `POST /webhook/whatsapp-inbound` | Núcleo: Claude, Supabase, respuesta al dueño y avisos al equipo |

## n8n Variables (Settings → Variables) — pon aquí los secretos/config

| Variable | Descripción |
|---|---|
| `Anthropic_API_key` | API key de Anthropic (Claude) |
| `SUPABASE_SERVICE_ROLE_KEY` | Service role key de Supabase (usada en los nodos Code vía REST) |
| `WA_PHONE_NUMBER_ID` | Phone Number ID de WhatsApp Cloud API |
| `WA_ACCESS_TOKEN` | Token de acceso de WhatsApp (usa un **System User token permanente**, no el temporal de 24h) |
| `CLINIC_EMAIL` | Correo de la clínica (remitente y destinatario del aviso de check-in completado) |
| `ONCALL_WA_PHONE` | WhatsApp del equipo de guardia en `+E.164` (destino del aviso de plantilla) |

> El bridge también valida un **verify token** de Meta, hardcodeado en el nodo `Token correcto?`
> (placeholder `YOUR_META_VERIFY_TOKEN`). Debe coincidir con el que pongas en la config de Meta.

## Credentials en n8n

- **Supabase API** — para los nodos Supabase (`Get many rows`, `Historial de mensajes`, `Create a row`).
  Además, algunos nodos Code llaman a la REST de Supabase directamente usando `$vars.SUPABASE_SERVICE_ROLE_KEY`
  y una URL de proyecto (placeholder `https://YOUR_SUPABASE_PROJECT.supabase.co` — sustitúyela).
- **SMTP** — para el nodo `Aviso email clínica` (Send Email). Sin esta credencial el workflow de
  Conversación **no se puede publicar**.

## Puesta en marcha

1. **Supabase:** ejecuta `db/schema.sql` (o adáptalo a tu esquema real). Sustituye
   `YOUR_SUPABASE_PROJECT` en los nodos Code de `postop-conversacion.json`.
2. **Importa** los 3 workflows en n8n (Workflows → Import from File).
3. **Variables:** crea las de la tabla de arriba.
4. **Credentials:** crea la de Supabase (y enlázala a los nodos Supabase) y la SMTP
   (y enlázala a `Aviso email clínica`).
5. **Verify token:** pon tu token real en el nodo `Token correcto?` del bridge (o parametrízalo).
6. **Meta** (App Dashboard → WhatsApp → Configuration): ver `docs/whatsapp-setup.md`.
7. **Plantilla de WhatsApp** `checkin_completado`: ver `docs/whatsapp-setup.md`.
8. **Publica/activa** los 3 workflows.

## Normalización de teléfono

Función `normalizePhone(raw, defaultCC='34')` **duplicada** en `Activación · Code in JavaScript`
y en el bridge `Normalizar mensaje`. Debe mantenerse **idéntica** en ambos para que el número
guardado en `follow_ups.owner_phone` coincida con el número usado en la búsqueda.
La regla «9 dígitos que empiezan por 6-9 → +34» es específica de España; para multi-país,
ajusta `defaultCC` o la regla nacional en **ambos** nodos.

## Notas técnicas

- Modelo: `claude-haiku-4-5-20251001`. El system prompt se parte en base estática (cacheable) +
  contexto dinámico por paciente.
- Marcadores de control emitidos por Claude: `[ALERTA:ROJO]`, `[ALERTA:AMARILLO]`, `[CHECK-IN:COMPLETO]`
  (+ JSON). Se parsean y se retiran del texto que ve el dueño.
- Formato: se convierte Markdown `**negrita**` → WhatsApp `*negrita*`.
- `messages.sender` acepta `owner` / `system`; `messages.direction` acepta `inbound` / `outbound`.
- La columna de resumen del check-in es `risk_summary` (no `summary`).
