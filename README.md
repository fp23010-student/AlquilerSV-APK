# Alquileres SV - App móvil

App Android (Flutter) para que propietarios de casas o locales pequeños gestionen
inquilinos, contratos y cobros, con recordatorios automáticos y recibos digitales.

## Qué hace
- Registra inmuebles, inquilinos y contratos. Al crear un contrato se generan los pagos mensuales.
- Calcula los días de atraso de cada pago y el promedio (métrica del tema).
- Funciona sin internet: guarda todo en el teléfono (SQLite) y sincroniza al reconectar.
- Recordatorios automáticos de pago (notificaciones locales) y recordatorio/recibo por WhatsApp.

## Arquitectura
App Flutter (SQLite local) <-> API en Rust (Axum) <-> CouchDB (Docker).
Servidor: ENLACE_AL_REPO_DE_LA_API

## Descargar e instalar
1. Descargar la APK: ENLACE_A_LA_APK
2. Permitir la instalación de orígenes desconocidos y aceptar las notificaciones.
3. Para sincronizar, levantar la API (ver su README) y poner su dirección en
   Ajustes -> Dirección de la API. Sin servidor, la app funciona igual, solo local.

## Desarrollo
flutter pub get
flutter run
