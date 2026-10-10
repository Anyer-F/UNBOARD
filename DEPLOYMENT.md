# Despliegue de UNBOUND

Pila contenerizada: **PostgreSQL + Backend (Spring Boot) + Web (nginx con HTTPS)**.

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
                           │ JDBC
                 ┌─────────▼───────────┐
                 │  postgres:16        │  :5432 (host:5433)
                 │  volumen postgres_data
                 └─────────────────────┘
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

- **Esquema de BD:** lo gestiona **Flyway** (`backend/src/main/resources/db/migration/V1..V5`).
  El backend arranca con `spring.jpa.hibernate.ddl-auto=none` — nunca dejar que Hibernate
  modifique el esquema en producción.
- **BD ya creada** (como la actual `unbound`): Flyway la *baselinea* en V1 y aplica V2..V5
  (`spring.flyway.baseline-on-migrate=true`). BD vacía: corre V1..V5 desde cero.
- **Uploads:** volumen `uploads_data` en `/app/uploads` (sobrevive a recreaciones del contenedor).
- **App móvil:** en *Ajustes → API* configurar la URL base. Para el emulador Android:
  `http://10.0.2.2:8081`; para un dispositivo real en la misma red: `http://<IP-del-host>:8081`;
  si solo se expone por nginx: `https://<dominio>`.
- **Escalar:** la app móvil no comparte sesiones (JWT stateless), así que el backend podría
  replicarse detrás de un balanceador sin cambios de código.

## Comandos útiles

```bash
docker compose down            # detener (los volúmenes persisten)
docker compose up -d --build backend   # reconstruir solo el backend
docker compose exec backend java -jar app.jar --help   # dentro del contenedor
docker compose logs web -f
```
