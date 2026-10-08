package com.example.backend.service;

import java.io.IOException;
import java.net.MalformedURLException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.nio.file.StandardCopyOption;
import java.util.UUID;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.core.io.UrlResource;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

import jakarta.annotation.PostConstruct;

@Service
public class FileStorageService {

    private final Path fileStorageLocation;

    public FileStorageService(@Value("${app.upload.dir:uploads}") String uploadDir) {
        this.fileStorageLocation = Paths.get(uploadDir).toAbsolutePath().normalize();
    }

    @PostConstruct
    public void init() {
        try {
            Files.createDirectories(this.fileStorageLocation);
        } catch (IOException ex) {
            throw new RuntimeException("No se pudo crear el directorio de almacenamiento de archivos en: " + this.fileStorageLocation, ex);
        }
    }

    public String storeFile(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new RuntimeException("No se puede guardar un archivo vacío.");
        }

        String originalFileName = StringUtils.cleanPath(file.getOriginalFilename() != null ? file.getOriginalFilename() : "documento");
        String extension = "";
        int dotIndex = originalFileName.lastIndexOf('.');
        if (dotIndex > 0) {
            extension = originalFileName.substring(dotIndex);
        }

        String storedFileName = UUID.randomUUID().toString() + extension;

        try {
            if (storedFileName.contains("..")) {
                throw new RuntimeException("El nombre del archivo contiene una ruta no válida: " + storedFileName);
            }

            Files.createDirectories(this.fileStorageLocation);
            Path targetLocation = this.fileStorageLocation.resolve(storedFileName).normalize();
            Files.copy(file.getInputStream(), targetLocation, StandardCopyOption.REPLACE_EXISTING);

            return storedFileName;
        } catch (IOException ex) {
            throw new RuntimeException("No se pudo almacenar el archivo " + storedFileName + ". Por favor intente de nuevo.", ex);
        }
    }

    public Resource loadFileAsResource(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            throw new RuntimeException("El nombre del archivo no puede estar vacío.");
        }

        try {
            String cleanFileName = Paths.get(fileName).getFileName().toString();
            Path filePath = this.fileStorageLocation.resolve(cleanFileName).normalize();

            // Si no existe directamente con cleanFileName, probar con la ruta original o rutas relativas alternativas
            if (!Files.exists(filePath) || !Files.isReadable(filePath)) {
                Path altPath = Paths.get(fileName).toAbsolutePath().normalize();
                if (Files.exists(altPath) && Files.isReadable(altPath)) {
                    filePath = altPath;
                } else {
                    Path fallback = Paths.get("uploads").resolve(cleanFileName).toAbsolutePath().normalize();
                    if (Files.exists(fallback) && Files.isReadable(fallback)) {
                        filePath = fallback;
                    }
                }
            }

            if (Files.exists(filePath) && Files.isReadable(filePath)) {
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

    public void deleteFile(String fileName) {
        if (fileName == null || fileName.isBlank()) {
            return;
        }
        try {
            String cleanFileName = Paths.get(fileName).getFileName().toString();
            Path filePath = this.fileStorageLocation.resolve(cleanFileName).normalize();
            Files.deleteIfExists(filePath);
        } catch (IOException ex) {
            System.err.println("No se pudo eliminar el archivo del disco: " + fileName + ". " + ex.getMessage());
        }
    }

    public Path getFileStorageLocation() {
        return this.fileStorageLocation;
    }
}
