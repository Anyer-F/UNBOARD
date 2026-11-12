package com.example.backend.service;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.ByteArrayResource;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import io.minio.errors.ErrorResponseException;
import jakarta.annotation.PostConstruct;
import lombok.extern.slf4j.Slf4j;

/**
 * Repositorio de documentos.
 *
 * - {@code app.storage.tipo=s3}: los archivos se guardan en un repositorio
 *   remoto compatible con S3 (SeaweedFS, MinIO, AWS S3...). En la base de
 *   datos solo quedan la clave y los metadatos.
 * - {@code app.storage.tipo=local} (por defecto): carpeta {@code app.upload.dir}.
 *
 * En modo S3, si un archivo no existe en el bucket se busca en la carpeta
 * local, para seguir sirviendo los archivos subidos antes de la migración.
 */
@Service
@Slf4j
public class FileStorageService {

    private final Path fileStorageLocation;
    private final String tipo;
    private final String endpoint;
    private final String accessKey;
    private final String secretKey;
    private final String bucket;
    private final String region;

    private MinioClient minio;

    public FileStorageService(
            @Value("${app.upload.dir:uploads}") String uploadDir,
            @Value("${app.storage.tipo:local}") String tipo,
            @Value("${app.storage.s3.endpoint:}") String endpoint,
            @Value("${app.storage.s3.access-key:}") String accessKey,
            @Value("${app.storage.s3.secret-key:}") String secretKey,
            @Value("${app.storage.s3.bucket:unboard}") String bucket,
            @Value("${app.storage.s3.region:us-east-1}") String region) {
        this.fileStorageLocation = Paths.get(uploadDir).toAbsolutePath().normalize();
        this.tipo = tipo;
        this.endpoint = endpoint;
        this.accessKey = accessKey;
        this.secretKey = secretKey;
        this.bucket = bucket;
        this.region = region;
    }

    @PostConstruct
    public void init() {
        try {
            Files.createDirectories(this.fileStorageLocation);
        } catch (IOException ex) {
            throw new RuntimeException("No se pudo crear el directorio de almacenamiento de archivos en: " + this.fileStorageLocation, ex);
        }
        if (esRemoto()) {
            minio = MinioClient.builder()
                    .endpoint(endpoint)
                    .credentials(accessKey, secretKey)
                    .region(region)
                    .build();
            asegurarBucket();
            log.info("Repositorio de documentos remoto (S3): {} / bucket {}", endpoint, bucket);
        } else {
            log.info("Repositorio de documentos local: {}", fileStorageLocation);
        }
    }

    public boolean esRemoto() {
        return "s3".equalsIgnoreCase(tipo) && endpoint != null && !endpoint.isBlank();
    }

    /**
     * Crea el bucket si no existe. Si el repositorio aún no está disponible
     * se reintenta en la primera escritura.
     */
    private boolean asegurarBucket() {
        try {
            if (!minio.bucketExists(BucketExistsArgs.builder().bucket(bucket).build())) {
                minio.makeBucket(MakeBucketArgs.builder().bucket(bucket).region(region).build());
            }
            return true;
        } catch (Exception e) {
            log.warn("No se pudo verificar el bucket '{}': {}", bucket, e.getMessage());
            return false;
        }
    }

    // ==================== ESCRITURA ====================

    public String storeFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new RuntimeException("No se puede guardar un archivo vacío.");
        }
        String originalFileName = StringUtils.cleanPath(
                file.getOriginalFilename() != null ? file.getOriginalFilename() : "documento");
        try (InputStream in = file.getInputStream()) {
            return guardar(in, file.getSize(), extension(originalFileName), file.getContentType());
        } catch (IOException ex) {
            throw new RuntimeException("No se pudo almacenar el archivo. Por favor intente de nuevo.", ex);
        }
    }

    /**
     * Guarda contenido generado por el sistema (ej. PDF o ZIP exportado).
     */
    public String storeBytes(byte[] contenido, String nombreArchivo, String contentType) {
        return guardar(new ByteArrayInputStream(contenido), contenido.length,
                extension(nombreArchivo), contentType);
    }

    private String guardar(InputStream in, long size, String extension, String contentType) {
        String clave = UUID.randomUUID() + extension;
        if (clave.contains("..")) {
            throw new RuntimeException("El nombre del archivo contiene una ruta no válida: " + clave);
        }
        try {
            if (esRemoto()) {
                asegurarBucket();
                minio.putObject(PutObjectArgs.builder()
                        .bucket(bucket)
                        .object(clave)
                        .stream(in, size, -1)
                        .contentType(contentType != null && !contentType.isBlank()
                                ? contentType : "application/octet-stream")
                        .build());
            } else {
                Files.createDirectories(this.fileStorageLocation);
                Files.copy(in, fileStorageLocation.resolve(clave).normalize(),
                        StandardCopyOption.REPLACE_EXISTING);
            }
            return clave;
        } catch (Exception ex) {
            throw new RuntimeException("No se pudo almacenar el archivo " + clave + ": " + ex.getMessage(), ex);
        }
    }

    // ==================== LECTURA ====================

    public Resource loadFileAsResource(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            throw new RuntimeException("El nombre del archivo no puede estar vacío.");
        }
        String clave = Paths.get(fileName).getFileName().toString();
        if (esRemoto()) {
            try (InputStream in = minio.getObject(GetObjectArgs.builder()
                    .bucket(bucket).object(clave).build())) {
                return new ByteArrayResource(in.readAllBytes());
            } catch (ErrorResponseException e) {
                // No está en el repositorio remoto: archivo anterior a la migración
                log.debug("{} no está en el bucket, se busca localmente", clave);
            } catch (Exception e) {
                throw new RuntimeException("No se pudo leer el archivo del repositorio: " + e.getMessage(), e);
            }
        }
        return cargarLocal(fileName, clave);
    }

    public byte[] readBytes(String fileName) {
        try (InputStream in = loadFileAsResource(fileName).getInputStream()) {
            return in.readAllBytes();
        } catch (IOException e) {
            throw new RuntimeException("No se pudo leer el archivo: " + fileName, e);
        }
    }

    private Resource cargarLocal(String fileName, String clave) {
        try {
            Path filePath = this.fileStorageLocation.resolve(clave).normalize();
            if (!Files.isReadable(filePath)) {
                Path fallback = Paths.get("uploads").resolve(clave).toAbsolutePath().normalize();
                if (Files.isReadable(fallback)) {
                    filePath = fallback;
                }
            }
            if (Files.isReadable(filePath)) {
                Resource resource = new UrlResource(filePath.toUri());
                if (resource.exists() && resource.isReadable()) {
                    return resource;
                }
            }
            throw new RuntimeException("El archivo físico no se encuentra en el servidor: " + fileName);
        } catch (MalformedURLException ex) {
            throw new RuntimeException("Ruta de archivo no válida: " + fileName, ex);
        }
    }

    // ==================== ELIMINACIÓN ====================

    public void deleteFile(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            return;
        }
        String clave = Paths.get(fileName).getFileName().toString();
        if (esRemoto()) {
            try {
                minio.removeObject(RemoveObjectArgs.builder().bucket(bucket).object(clave).build());
            } catch (Exception e) {
                log.warn("No se pudo eliminar {} del repositorio: {}", clave, e.getMessage());
            }
        }
        try {
            Files.deleteIfExists(this.fileStorageLocation.resolve(clave).normalize());
        } catch (IOException ex) {
            log.warn("No se pudo eliminar el archivo local {}: {}", clave, ex.getMessage());
        }
    }

    private static String extension(String nombre) {
        if (nombre == null) {
            return "";
        }
        int dot = nombre.lastIndexOf('.');
        if (dot <= 0 || dot == nombre.length() - 1) {
            return "";
        }
        String ext = nombre.substring(dot).toLowerCase();
        return ext.matches("\\.[a-z0-9]{1,8}") ? ext : "";
    }
}
