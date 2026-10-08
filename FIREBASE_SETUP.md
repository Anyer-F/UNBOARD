# Configuración de Firebase Cloud Messaging (FCM) - UNBOUND

Este documento explica cómo configurar las notificaciones push para la aplicación UNBOUND.

---

## 📋 Requisitos previos

1. Tener una cuenta de Google
2. Tener un proyecto en [Firebase Console](https://console.firebase.google.com/)
3. Tener el backend y el móvil configurados

---

## 🔧 Configuración del Backend

### 1. Crear proyecto en Firebase

1. Ir a [Firebase Console](https://console.firebase.google.com/)
2. Click en **"Agregar proyecto"** o **"Create project"**
3. Nombre del proyecto: `unbound-huehuetenango`
4. Desactivar Google Analytics (opcional)
5. Click en **"Crear proyecto"**

### 2. Generar cuenta de servicio

1. Ir a **Configuración del proyecto** (icono de engranaje)
2. Ir a la pestaña **"Cuentas de servicio"**
3. Click en **"Generar nueva clave privada"**
4. Se descargará un archivo JSON (guárdalo como `serviceAccountKey.json`)

### 3. Colocar el archivo en el backend

1. Crear la carpeta `backend/src/main/resources/` si no existe
2. Copiar el archivo `serviceAccountKey.json` a `backend/src/main/resources/`

### 4. Verificar application.properties

Asegúrate de que `backend/src/main/resources/application.properties` contenga:

```properties
firebase.service-account=serviceAccountKey.json
```

### 5. Verificar pom.xml

Asegúrate de que `backend/pom.xml` contenga la dependencia:

```xml
<dependency>
    <groupId>com.google.firebase</groupId>
    <artifactId>firebase-admin</artifactId>
    <version>10.0.0</version>
</dependency>
```

---

## 📱 Configuración del Móvil (Flutter)

### 1. Crear app Android en Firebase

1. En Firebase Console, ir a **"Descripción general"**
2. Click en el ícono de **Android** para agregar app
3. Paquete: `com.example.unbound_mobile`
4. Apodo: `UNBOUND`
5. Descargar el archivo `google-services.json`
6. Click en **"Siguiente"** y **"Continuar"**

### 2. Colocar google-services.json

Copiar el archivo `google-services.json` a:
```
mobile/android/app/google-services.json
```

### 3. Configurar build.gradle

En `mobile/android/build.gradle`, en el bloque `buildscript`, agregar:

```groovy
buildscript {
    dependencies {
        classpath 'com.google.gms:google-services:4.4.2'
    }
}
```

En `mobile/android/app/build.gradle`, agregar al final:

```groovy
apply plugin: 'com.google.gms.google-services'
```

### 4. Configurar AndroidManifest.xml

En `mobile/android/app/src/main/AndroidManifest.xml`, agregar dentro de `<application>`:

```xml
<service
    android:name=".MyFirebaseMessagingService"
    android:exported="false">
    <intent-filter>
        <action android:name="com.google.firebase.MESSAGING_EVENT" />
    </intent-filter>
</service>

<meta-data
    android:name="com.google.firebase.messaging.default_notification_channel_id"
    android:value="unbound_notifications" />
```

### 5. Configurar pubspec.yaml

Asegúrate de que `mobile/pubspec.yaml` contenga:

```yaml
dependencies:
  firebase_core: ^3.13.0
  firebase_messaging: ^15.2.5
  flutter_local_notifications: ^17.2.4
```

### 6. Ejecutar flutter pub get

```bash
cd mobile
flutter pub get
```

---

## 🧪 Probar las Notificaciones Push

### 1. Ejecutar el backend

```bash
cd backend
mvn spring-boot:run
```

### 2. Ejecutar la app móvil

```bash
cd mobile
flutter run
```

### 3. Enviar notificación de prueba

Desde Firebase Console:
1. Ir a **Cloud Messaging**
2. Click en **"Enviar tu primer mensaje"**
3. Escribir título y mensaje
4. Click en **"Enviar mensaje"**

---

## 🔍 Verificación

### Backend
- [ ] Firebase Admin SDK se inicializa sin errores
- [ ] El endpoint `/api/fcm/registrar-token` responde correctamente
- [ ] Las notificaciones push se envían cuando se crea una notificación

### Móvil
- [ ] La app solicita permisos de notificación
- [ ] Se obtiene el FCM Token
- [ ] El token se registra en el backend
- [ ] Se reciben notificaciones push

---

## 📝 Endpoints de Notificaciones

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/api/notificaciones/usuario/{id}` | Listar notificaciones |
| GET | `/api/notificaciones/usuario/{id}/conteo-no-leidas` | Contar no leídas |
| PATCH | `/api/notificaciones/{id}/leer` | Marcar como leída |
| PATCH | `/api/notificaciones/usuario/{id}/leer-todas` | Marcar todas como leídas |
| POST | `/api/fcm/registrar-token` | Registrar token FCM |
| POST | `/api/fcm/suscribir-tema` | Suscribir a tema |

---

## ⚠️ Notas importantes

1. **El archivo `serviceAccountKey.json` NO debe subirse a git**. Agregarlo a `.gitignore`.
2. **El archivo `google-services.json` NO debe subirse a git**. Agregarlo a `.gitignore`.
3. Para iOS, se requiere configuración adicional en Apple Developer Console.
4. Las notificaciones push requieren conexión a internet.
5. En Android 13+, se requiere permiso explícito de notificación.

---

## 🐛 Solución de problemas

### Error: "Firebase Admin SDK no inicializado"
- Verificar que `serviceAccountKey.json` está en `backend/src/main/resources/`
- Verificar que la ruta en `application.properties` es correcta

### Error: "Default FirebaseApp does not exist"
- Verificar que `firebase_core` está correctamente configurado
- Ejecutar `flutter clean` y `flutter pub get`

### No se reciben notificaciones
- Verificar que el token FCM se registró correctamente en el backend
- Verificar permisos de notificación en el dispositivo
- Verificar que el backend está ejecutándose y accesible
