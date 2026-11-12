# Despliegue de UNBOARD

Pila contenerizada: **PostgreSQL + repositorio de documentos S3 (SeaweedFS) + Backend (Spring Boot) + Web (nginx con HTTPS)**.

```
                 ┌─────────────────────┐
  Navegador/App  │   nginx (web)       │  :80 → 301 https
  ──────────────▶│   :443 (TLS)        │
   /api/*        │   /  → build web    │
                 └─────────┬───────────┘
                           │ proxy /api
                 ┌─────────▼───────────┐
                 │  backend (Spring)   │  :8081  (expuesto directo
                 └─────────┬───────────┘          para la app móvil)
                     JDBC  │        │ S3 (archivos, PDF/ZIP)
                 ┌─────────▼──┐  ┌──▼──────────────────┐
                 │ postgres:16│  │ storage (SeaweedFS) │  solo red interna
                 │ :5432      │  │ :8333 API S3        │
                 │ (host:5433)│  │ volumen storage_data│
                 └────────────┘  └─────────────────────┘
```

## Levantar la pila

```bash
docker compose up -d --build
docker compose ps          # estado / healthchecks
docker compose logs -f backend
```

Variables de entorno en **`.env`** (git-ignorado, ya creado):

| Variable | Requisito |
|---|---|
| `APP_JWT_SECRET` | ≥ 32 caracteres. Firma los JWT; si cambia, todos los tokens quedan inválidos. |
| `S3_ACCESS_KEY` / `S3_SECRET_KEY` | Credenciales del repositorio de documentos (S3). Se generan en `.env`; el backend y SeaweedFS las comparten. |
| `POSTGRES_PASSWORD` | Solo aplica en la **primera** inicialización del volumen. En una BD existente, cambiarla requiere `ALTER USER postgres PASSWORD ...` dentro del contenedor. |

Endpoints resultantes:

| Servicio | URL |
|---|---|
| API (móvil / directo) | `http://<host>:8081` — la app móvil usa esto como *base URL* (ella agrega `/api/...`) |
| App web | `https://localhost/` (HTTPS, mismo origen para `/api`) |
| API por HTTPS | `https://localhost/api/...` (proxy nginx → backend) |
| Swagger | `http://<host>:8081/swagger-ui.html` |

## HTTPS

**Ahora mismo:** certificado **self-signed** en `deploy/web/certs/` (generado con
`openssl` del contenedor postgres, CN=localhost, 365 días). El navegador avisará
que no es de confianza — aceptar el riesgo para pruebas locales.

**Producción:** reemplazar por certificados reales. Dos opciones:

1. **Let's Encrypt + certbot** (con un dominio apuntando al host):
   ```bash
   docker run -it --rm -v /etc/letsencrypt:/etc/letsencrypt -v /var/www/letsencrypt:/var/www/letsencrypt \
     certbot/certbot certonly --webroot -w /var/www/letsencrypt -d tudominio.com
   # montar los certs en el servicio web:
   #   deploy/web/certs/tls.crt -> /etc/letsencrypt/live/tudominio.com/fullchain.pem
   #   deploy/web/certs/tls.key -> /etc/letsencrypt/live/tudominio.com/privkey.pem
   ```
2. **Caddy** en lugar de nginx: HTTPS automático sin configuración manual.

Los archivos de certs están en `.gitignore` — nunca commitear claves privadas.

## Notas de operación

- **Esquema de BD:** lo gestiona **Flyway** (`backend/src/main/resources/db/migration/V1..V6`).
  El backend arranca con `spring.jpa.hibernate.ddl-auto=none` — nunca dejar que Hibernate
  modifique el esquema en producción.
- **BD ya creada** (como la actual `unbound`): Flyway la *baselinea* en V1 y aplica V2..V6
  (`spring.flyway.baseline-on-migrate=true`). BD vacía: corre V1..V6 desde cero.
- **V6 (Descripción del proyecto v2):** módulos por comunidad, actividades compartidas con
  tipo (Tarea / Anuncio / Material de apoyo), una asignación por apadrinado, entregas con
  versiones, sugerencias, observaciones, exportaciones e historial general. Convierte los
  datos anteriores sin pérdida (cada actividad previa queda con su asignación y el material
  de apoyo por comunidad pasa a ser una actividad de tipo Material de apoyo).
- **Repositorio de documentos:** con `APP_STORAGE_TIPO=s3` (docker-compose) los archivos de
  las entregas, el material de los coordinadores y los PDF/ZIP generados se guardan en el
  servicio `storage` (API S3, volumen `storage_data`); la base de datos solo guarda la clave
  y los metadatos. Para usar otro proveedor S3 (AWS, MinIO, etc.) basta con cambiar
  `APP_STORAGE_S3_ENDPOINT` y las credenciales. Sin esa variable (desarrollo local) se usa
  la carpeta `uploads/`. Los archivos subidos antes de V6 siguen en el volumen
  `uploads_data` y se sirven desde ahí.
- **Exportaciones:** los PDF/ZIP quedan disponibles 24 h (`app.exportaciones.horas-disponible`);
  luego una tarea programada los elimina del repositorio (el registro queda en el historial).
- **Tareas programadas:** cada hora se marcan las tareas vencidas y se envía el recordatorio
  de "próxima fecha límite" (3 días antes).
- **App móvil:** en *Ajustes → API* configurar la URL base. Para el emulador Android:
  `http://10.0.2.2:8081`; para un dispositivo real en la misma red: `http://<IP-del-host>:8081`;
  si solo se expone por nginx: `https://<dominio>`.
- **Escalar:** la app móvil no comparte sesiones (JWT stateless), así que el backend podría
  replicarse detrás de un balanceador sin cambios de código.

## Pruebas

```bash
# Pruebas unitarias del backend (JDK 21; sin Java local se pueden correr en Docker)
docker run --rm -v "$PWD/backend:/app" -w /app maven:3.9-eclipse-temurin-21-alpine \n  mvn -q test "-Dtest=!BackendApplicationTests" -Dsurefire.failIfNoSpecifiedTests=false

# Prueba de extremo a extremo del flujo completo (con la pila levantada)
node faseG_tests.mjs
```

## Comandos útiles

```bash
docker compose down            # detener (los volúmenes persisten)
docker compose up -d --build backend   # reconstruir solo el backend
docker compose exec backend java -jar app.jar --help   # dentro del contenedor
docker compose logs web -f
```
