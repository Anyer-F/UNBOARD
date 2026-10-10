# syntax=docker/dockerfile:1
# ==================== Etapa 1: construir el JAR ====================
FROM maven:3.9-eclipse-temurin-21-alpine AS build
WORKDIR /app

COPY pom.xml .
COPY src ./src

# Nota: NO usar "dependency:go-offline" — ese goal descarga tambien
# las dependencias OPCIONALES de flyway-core (GCS/S3/ojdbc), cuyo
# grafo de POMs necesita repos inalcanzables (S3 / GitHub Packages).
# El classpath de compilacion ya las excluye (ver pom.xml).
# El cache mount hace que las dependencias persistan en el host
# entre builds (reconstrucciones rapidas).
RUN --mount=type=cache,target=/root/.m2 mvn package -DskipTests

# ==================== Etapa 2: runtime ====================
FROM eclipse-temurin:21-jre-alpine
WORKDIR /app

COPY --from=build /app/target/backend-0.0.1-SNAPSHOT.jar app.jar

# Usuario no root + carpeta de uploads
RUN addgroup -S app && adduser -S app -G app \
    && mkdir -p uploads && chown -R app:app /app
USER app

EXPOSE 8081

# El esquema lo gestiona Flyway (spring.flyway.* en application.properties).
# APP_JWT_SECRET y la BD se inyectan por variables de entorno (ver docker-compose.yml).
ENTRYPOINT ["java", "-jar", "app.jar"]
