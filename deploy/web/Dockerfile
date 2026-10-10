# Servidor de la app web (Flutter build) + reverse proxy de la API.
# Contexto de build: raiz del proyecto (accede a mobile/build/web).
FROM nginx:alpine

COPY deploy/web/nginx.conf /etc/nginx/conf.d/default.conf
COPY mobile/build/web /usr/share/nginx/html
COPY deploy/web/certs /etc/nginx/certs

EXPOSE 80 443
