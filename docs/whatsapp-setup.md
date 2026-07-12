# Configuración de WhatsApp Cloud API (Meta)

## 1. Webhook (App Dashboard → WhatsApp → Configuration)

- **Callback URL:** `https://<TU_HOST_N8N>/webhook/whatsapp-meta`
- **Verify token:** el mismo valor que pongas en el nodo `Token correcto?` del bridge
  (en el repo está como `YOUR_META_VERIFY_TOKEN`).
- Pulsa **Verify and save** → Meta hace un `GET` con `hub.challenge`; el bridge responde con el
  challenge y queda verificado.
- **Suscribe el campo `messages`.**

## 2. Suscribir la WABA a tu app (causa habitual de "verifica pero no llegan mensajes")

Verificar el webhook **no** suscribe la WhatsApp Business Account (WABA) a tu app. Compruébalo:

```
GET https://graph.facebook.com/v21.0/<WABA_ID>/subscribed_apps      # ¿aparece tu app?
POST https://graph.facebook.com/v21.0/<WABA_ID>/subscribed_apps     # suscribir tu app
```
(con el token de la app). Si la WABA está suscrita a otra app (p.ej. una de pruebas de Meta),
los mensajes se procesan pero **nunca** llegan a tu callback.

## 3. Modo de la app

En modo Desarrollo solo fluyen mensajes de números con rol/tester en la app, y los envíos
salientes de texto libre solo llegan a destinatarios de la lista de prueba. Para producción real,
pasa la app a Live y usa un número de producción.

## 4. Token de acceso

Usa un **System User token permanente** (Business Settings → Users → System Users → Generate token,
scopes `whatsapp_business_messaging` + `whatsapp_business_management`). Evita el token temporal de
API Setup (caduca a las ~24h). Ponlo en la variable n8n `WA_ACCESS_TOKEN`.

## 5. Ventana de 24h y plantillas

- **Respuesta al dueño** (texto libre): solo se entrega dentro de la ventana de 24h que se abre
  cuando el dueño escribe primero. Como el dueño siempre inicia, esto se cumple solo.
- **Aviso al equipo de guardia** (mensaje iniciado por el negocio, fuera de ventana): requiere
  **plantilla aprobada**.

## 6. Plantilla `checkin_completado` (WhatsApp Manager → Message Templates)

- **Nombre:** `checkin_completado`
- **Idioma:** Español (`es`)
- **Categoría:** Utility
- **Body (4 variables, en este orden):**

  ```
  Check-in postoperatorio completado en Anicura Lleida.
  Paciente: {{1}}
  Nivel de riesgo: {{2}}
  Resumen: {{3}}
  Propietario: {{4}}
  ```

- Ejemplos para aprobación: `{{1}}`=Max, `{{2}}`=VERDE, `{{3}}`=Recuperación normal sin incidencias,
  `{{4}}`=Propietario Prueba (+34XXXXXXXXX)
- El orden de variables debe coincidir con `wa_params` del nodo `Construir aviso equipo`:
  `[patient_name, risk, summary, "owner_name (owner_phone)"]`.
- El número de `ONCALL_WA_PHONE` debe estar en la lista de destinatarios de prueba mientras la app
  esté en modo Desarrollo.
