package com.example.backend.service;

import java.nio.file.Files;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.core.io.Resource;
import org.springframework.http.MediaTypeFactory;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Documento;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.UsuarioRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class DocumentoService {

    private final DocumentoRepository documentoRepository;
    private final ExpedienteRepository expedienteRepository;
    private final ActividadRepository actividadRepository;
    private final UsuarioRepository usuarioRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final FileStorageService fileStorageService;
    private final NotificacionService notificacionService;
    private final HistorialActividadService historialActividadService;

    @Transactional
    public DocumentoResponseDTO subirDocumento(
            MultipartFile file,
            Long apadrinadoId,
            Long expedienteId,
            Long actividadId,
            TipoDocumento tipoDocumento,
            String descripcion,
            Long usuarioId) {

        if (file == null || file.isEmpty()) {
            throw new RuntimeException("El archivo proporcionado está vacío o no fue enviado.");
        }

        // 1. Si viene actividadId, cargar actividad e inferir apadrinado si no viene
        Actividad actividad = null;
        if (actividadId != null) {
            actividad = actividadRepository.findById(actividadId)
                    .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + actividadId));
            
            if (apadrinadoId == null && actividad.getApadrinado() != null) {
                apadrinadoId = actividad.getApadrinado().getId();
            }
        }

        // 2. Si viene usuarioId y apadrinadoId es nulo, intentar buscar si el usuario es un apadrinado
        if (apadrinadoId == null && usuarioId != null) {
            var apadrinadoOpt = apadrinadoRepository.findByUsuarioId(usuarioId);
            if (apadrinadoOpt.isPresent()) {
                apadrinadoId = apadrinadoOpt.get().getId();
            }
        }

        // 3. Si aún no hay apadrinadoId ni expedienteId, revisar si el usuario autenticado en Spring Security es apadrinado
        if (expedienteId == null && apadrinadoId == null) {
            try {
                Authentication auth = SecurityContextHolder.getContext().getAuthentication();
                if (auth != null && auth.isAuthenticated() && !auth.getName().equals("anonymousUser")) {
                    var userOpt = usuarioRepository.findByCorreo(auth.getName());
                    if (userOpt.isPresent()) {
                        var apOpt = apadrinadoRepository.findByUsuarioId(userOpt.get().getId());
                        if (apOpt.isPresent()) {
                            apadrinadoId = apOpt.get().getId();
                        }
                    }
                }
            } catch (Exception ignored) {}
        }

        // 4. Obtener o crear automáticamente el expediente
        Expediente expediente = null;
        if (expedienteId != null) {
            expediente = expedienteRepository.findById(expedienteId)
                    .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + expedienteId));
        } else if (apadrinadoId != null) {
            final Long finalApadrinadoId = apadrinadoId;
            expediente = expedienteRepository.findByApadrinadoId(finalApadrinadoId)
                    .orElseGet(() -> {
                        Apadrinado ap = apadrinadoRepository.findById(finalApadrinadoId)
                                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con ID: " + finalApadrinadoId));
                        return expedienteRepository.save(Expediente.builder()
                                .apadrinado(ap)
                                .fechaCreacion(LocalDate.now())
                                .build());
                    });
        } else {
            throw new RuntimeException("Debe especificar al menos un 'apadrinadoId', 'expedienteId' o 'actividadId' válido para asociar el documento.");
        }

        // 5. Asociar usuario que sube el archivo
        Usuario subidoPor = null;
        if (usuarioId != null) {
            subidoPor = usuarioRepository.findById(usuarioId).orElse(null);
        }
        if (subidoPor == null) {
            try {
                Authentication auth = SecurityContextHolder.getContext().getAuthentication();
                if (auth != null && auth.isAuthenticated() && !auth.getName().equals("anonymousUser")) {
                    subidoPor = usuarioRepository.findByCorreo(auth.getName()).orElse(null);
                }
            } catch (Exception ignored) {}
        }

        // 6. Si la actividad está en PENDIENTE, EN_PROCESO o CORRECCION_SOLICITADA, actualizar automáticamente a ENTREGADA
        if (actividad != null) {
            EstadoActividad estadoPrevio = actividad.getEstado();
            if (actividad.getEstado() == EstadoActividad.PENDIENTE 
                    || actividad.getEstado() == EstadoActividad.EN_PROCESO
                    || actividad.getEstado() == EstadoActividad.CORRECCION_SOLICITADA) {
                actividad.setEstado(EstadoActividad.ENTREGADA);
                actividadRepository.save(actividad);

                String nota = (file.getOriginalFilename() != null ? file.getOriginalFilename() : "documento")
                        + (descripcion != null && !descripcion.isBlank() ? " - " + descripcion : "");
                historialActividadService.registrarCambio(
                        actividad,
                        estadoPrevio,
                        EstadoActividad.ENTREGADA,
                        "ENTREGA DE EVIDENCIAS",
                        nota,
                        subidoPor
                );
            } else {
                String nota = "Archivo adicional adjuntado: " + (file.getOriginalFilename() != null ? file.getOriginalFilename() : "documento");
                historialActividadService.registrarCambio(
                        actividad,
                        estadoPrevio,
                        estadoPrevio,
                        "ADJUNCIÓN DE ARCHIVO",
                        nota,
                        subidoPor
                );
            }
        }

        // 7. Guardar archivo físico en disco
        String storedFileName = fileStorageService.storeFile(file);
        String relativePath = "uploads/" + storedFileName;
        String originalFileName = file.getOriginalFilename() != null ? file.getOriginalFilename() : "documento";

        // 8. Determinar tipo MIME exacto
        String mimeType = file.getContentType();
        if (mimeType == null || mimeType.isBlank() || mimeType.equals("application/octet-stream")) {
            mimeType = MediaTypeFactory.getMediaType(originalFileName)
                    .map(org.springframework.http.MediaType::toString)
                    .orElse("application/octet-stream");
        }

        // 9. Inferir tipo de documento si no se proporcionó
        if (tipoDocumento == null) {
            String lowerName = originalFileName.toLowerCase();
            String lowerMime = mimeType != null ? mimeType.toLowerCase() : "";
            if (lowerMime.startsWith("image/") || lowerName.endsWith(".jpg") || lowerName.endsWith(".jpeg") || lowerName.endsWith(".png") || lowerName.endsWith(".webp")) {
                tipoDocumento = TipoDocumento.FOTOGRAFIA;
            } else if (actividad != null) {
                tipoDocumento = TipoDocumento.EVIDENCIA;
            } else if (lowerName.contains("carta")) {
                tipoDocumento = TipoDocumento.CARTA;
            } else if (lowerName.contains("form") || lowerName.contains("formulario")) {
                tipoDocumento = TipoDocumento.FORMULARIO;
            } else {
                tipoDocumento = TipoDocumento.OTRO;
            }
        }

        Documento documento = Documento.builder()
                .nombreOriginal(originalFileName)
                .nombreAlmacenado(storedFileName)
                .rutaArchivo(relativePath)
                .tipoMime(mimeType)
                .tamanioBytes(file.getSize())
                .fechaSubida(LocalDateTime.now())
                .tipoDocumento(tipoDocumento)
                .descripcion(descripcion)
                .expediente(expediente)
                .actividad(actividad)
                .subidoPor(subidoPor)
                .build();

        Documento guardado = documentoRepository.save(documento);

        // Notificación automática al coordinador si se subió un documento para una actividad
        if (actividad != null && actividad.getCoordinador() != null && actividad.getCoordinador().getUsuario() != null) {
            String apNombre = (actividad.getApadrinado() != null && actividad.getApadrinado().getUsuario() != null)
                    ? actividad.getApadrinado().getUsuario().getNombre()
                    : "Un apadrinado";
            notificacionService.notificar(
                    actividad.getCoordinador().getUsuario(),
                    "Nueva entrega de actividad",
                    "El beneficiario " + apNombre + " ha subido evidencia para la actividad: '" + actividad.getTitulo() + "'",
                    com.example.backend.entity.TipoNotificacion.ENTREGA_ACTIVIDAD,
                    actividad.getId(),
                    "ACTIVIDAD"
            );
        }

        return convertirAResponseDTO(guardado);
    }

    @Transactional(readOnly = true)
    public Documento obtenerEntidad(Long id) {
        return documentoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Documento no encontrado con ID: " + id));
    }

    @Transactional(readOnly = true)
    public DocumentoResponseDTO obtenerPorId(Long id) {
        return convertirAResponseDTO(obtenerEntidad(id));
    }

    @Transactional(readOnly = true)
    public Resource cargarArchivoComoRecurso(Long id) {
        Documento doc = obtenerEntidad(id);
        return fileStorageService.loadFileAsResource(doc.getNombreAlmacenado());
    }

    @Transactional(readOnly = true)
    public Resource cargarArchivoPorNombre(String nombreAlmacenado) {
        return fileStorageService.loadFileAsResource(nombreAlmacenado);
    }

    @Transactional(readOnly = true)
    public List<DocumentoResponseDTO> listarPorExpediente(Long expedienteId, TipoDocumento tipoDocumento) {
        List<Documento> lista;
        if (tipoDocumento != null) {
            lista = documentoRepository.findByExpedienteIdAndTipoDocumento(expedienteId, tipoDocumento);
        } else {
            lista = documentoRepository.findByExpedienteId(expedienteId);
        }
        return lista.stream().map(this::convertirAResponseDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<DocumentoResponseDTO> listarPorApadrinado(Long apadrinadoId, TipoDocumento tipoDocumento) {
        List<Documento> lista;
        if (tipoDocumento != null) {
            lista = documentoRepository.findByExpedienteApadrinadoIdAndTipoDocumento(apadrinadoId, tipoDocumento);
        } else {
            lista = documentoRepository.findByExpedienteApadrinadoId(apadrinadoId);
        }
        return lista.stream().map(this::convertirAResponseDTO).collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public List<DocumentoResponseDTO> listarPorActividad(Long actividadId) {
        return documentoRepository.findByActividadId(actividadId).stream()
                .map(this::convertirAResponseDTO)
                .collect(Collectors.toList());
    }

    @Transactional
    public void eliminar(Long id) {
        Documento doc = obtenerEntidad(id);
        fileStorageService.deleteFile(doc.getNombreAlmacenado());
        documentoRepository.delete(doc);
    }

    public DocumentoResponseDTO convertirAResponseDTO(Documento doc) {
        String apadrinadoNombre = null;
        Long apadrinadoId = null;
        Long expId = null;

        if (doc.getExpediente() != null) {
            expId = doc.getExpediente().getId();
            if (doc.getExpediente().getApadrinado() != null) {
                apadrinadoId = doc.getExpediente().getApadrinado().getId();
                if (doc.getExpediente().getApadrinado().getUsuario() != null) {
                    apadrinadoNombre = doc.getExpediente().getApadrinado().getUsuario().getNombre();
                }
            }
        }

        String actTitulo = null;
        Long actId = null;
        if (doc.getActividad() != null) {
            actId = doc.getActividad().getId();
            actTitulo = doc.getActividad().getTitulo();
        }

        String subidoPorNombre = null;
        Long subidoPorId = null;
        if (doc.getSubidoPor() != null) {
            subidoPorId = doc.getSubidoPor().getId();
            subidoPorNombre = doc.getSubidoPor().getNombre();
        }

        String urlDescarga = "/api/documentos/" + doc.getId() + "/descargar";

        return DocumentoResponseDTO.builder()
                .id(doc.getId())
                .nombreOriginal(doc.getNombreOriginal())
                .nombreAlmacenado(doc.getNombreAlmacenado())
                .urlDescarga(urlDescarga)
                .tipoMime(doc.getTipoMime())
                .tamanioBytes(doc.getTamanioBytes())
                .fechaSubida(doc.getFechaSubida())
                .tipoDocumento(doc.getTipoDocumento())
                .descripcion(doc.getDescripcion())
                .expedienteId(expId)
                .apadrinadoId(apadrinadoId)
                .apadrinadoNombre(apadrinadoNombre)
                .actividadId(actId)
                .actividadTitulo(actTitulo)
                .subidoPorUsuarioId(subidoPorId)
                .subidoPorNombre(subidoPorNombre)
                .build();
    }
}
