package com.example.backend.service;

import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.core.io.Resource;
import org.springframework.http.MediaTypeFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Documento;
import com.example.backend.entity.Entrega;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.OrigenDocumento;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.DocumentoRepository;

import lombok.RequiredArgsConstructor;

/**
 * Gestión documental: los archivos se guardan en el repositorio de
 * documentos y en la base de datos quedan sus referencias y metadatos
 * (tipo, fecha, apadrinado, actividad, origen y estado).
 */
@Service
@RequiredArgsConstructor
public class DocumentoService {

    private final DocumentoRepository documentoRepository;
    private final FileStorageService fileStorageService;
    private final ConvertidorDTO convertidor;

    /**
     * Guarda el archivo y registra sus metadatos.
     *
     * @param expediente expediente del apadrinado (null para material del coordinador)
     * @param entrega    versión de la entrega (null para material del coordinador)
     */
    @Transactional
    public Documento guardar(
            MultipartFile file,
            TipoDocumento tipoDocumento,
            OrigenDocumento origen,
            Actividad actividad,
            Entrega entrega,
            Expediente expediente,
            Usuario subidoPor,
            String descripcion) {
        if (file == null || file.isEmpty()) {
            throw new RuntimeException("El archivo proporcionado está vacío o no fue enviado.");
        }
        String nombreOriginal = file.getOriginalFilename() != null && !file.getOriginalFilename().isBlank()
                ? file.getOriginalFilename() : "documento";
        String mime = file.getContentType();
        if (mime == null || mime.isBlank() || mime.equals("application/octet-stream")) {
            mime = MediaTypeFactory.getMediaType(nombreOriginal)
                    .map(org.springframework.http.MediaType::toString)
                    .orElse("application/octet-stream");
        }
        if (tipoDocumento == null) {
            tipoDocumento = inferirTipo(nombreOriginal, mime, origen);
        }
        String clave = fileStorageService.storeFile(file);
        return documentoRepository.save(Documento.builder()
                .nombreOriginal(nombreOriginal)
                .nombreAlmacenado(clave)
                .rutaArchivo(clave)
                .tipoMime(mime)
                .tamanioBytes(file.getSize())
                .fechaSubida(LocalDateTime.now())
                .tipoDocumento(tipoDocumento)
                .descripcion(descripcion != null && !descripcion.isBlank() ? descripcion.trim() : null)
                .origen(origen)
                .actividad(actividad)
                .entrega(entrega)
                .expediente(expediente)
                .subidoPor(subidoPor)
                .build());
    }

    public static TipoDocumento inferirTipo(String nombre, String mime, OrigenDocumento origen) {
        String n = nombre.toLowerCase();
        String m = mime != null ? mime.toLowerCase() : "";
        if (m.startsWith("image/") || n.matches(".*\\.(jpg|jpeg|png|webp|gif|heic)$")) {
            return TipoDocumento.FOTOGRAFIA;
        }
        if (origen == OrigenDocumento.COORDINADOR) {
            return n.contains("formulario") ? TipoDocumento.FORMULARIO : TipoDocumento.MATERIAL;
        }
        return TipoDocumento.DOCUMENTO;
    }

    /**
     * Copia la referencia de un documento a otra versión de la entrega.
     * El archivo físico se comparte (no se duplica).
     */
    @Transactional
    public Documento copiarAEntrega(Documento original, Entrega destino) {
        return documentoRepository.save(Documento.builder()
                .nombreOriginal(original.getNombreOriginal())
                .nombreAlmacenado(original.getNombreAlmacenado())
                .rutaArchivo(original.getRutaArchivo())
                .tipoMime(original.getTipoMime())
                .tamanioBytes(original.getTamanioBytes())
                .fechaSubida(original.getFechaSubida())
                .tipoDocumento(original.getTipoDocumento())
                .descripcion(original.getDescripcion())
                .origen(original.getOrigen())
                .actividad(original.getActividad())
                .entrega(destino)
                .expediente(original.getExpediente())
                .subidoPor(original.getSubidoPor())
                .build());
    }

    /**
     * Elimina el registro y, si ningún otro documento usa el mismo
     * archivo, también el archivo del repositorio.
     */
    @Transactional
    public void eliminar(Documento documento) {
        String clave = documento.getNombreAlmacenado();
        documentoRepository.delete(documento);
        documentoRepository.flush();
        if (documentoRepository.countByNombreAlmacenado(clave) == 0) {
            fileStorageService.deleteFile(clave);
        }
    }

    @Transactional
    public void eliminarTodos(List<Documento> documentos) {
        for (Documento d : documentos) {
            eliminar(d);
        }
    }

    // ==================== CONSULTA ====================

    @Transactional(readOnly = true)
    public Documento obtenerEntidad(Long id) {
        return documentoRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Documento no encontrado con ID: " + id));
    }

    @Transactional(readOnly = true)
    public DocumentoResponseDTO obtenerPorId(Long id) {
        return convertidor.documento(obtenerEntidad(id));
    }

    @Transactional(readOnly = true)
    public Resource cargarArchivoComoRecurso(Long id) {
        return fileStorageService.loadFileAsResource(obtenerEntidad(id).getNombreAlmacenado());
    }

    /** Documentos del expediente de un apadrinado, con filtros opcionales. */
    @Transactional(readOnly = true)
    public List<DocumentoResponseDTO> listarPorApadrinado(
            Long apadrinadoId, TipoDocumento tipo, Long actividadId, String estado) {
        return documentoRepository.findByExpedienteApadrinadoId(apadrinadoId).stream()
                .filter(d -> tipo == null || d.getTipoDocumento() == tipo)
                .filter(d -> actividadId == null
                        || (d.getActividad() != null && d.getActividad().getId().equals(actividadId)))
                .sorted(Comparator.comparing(Documento::getFechaSubida,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .map(convertidor::documento)
                .filter(d -> estado == null || estado.equalsIgnoreCase(d.getEstado()))
                .collect(Collectors.toList());
    }
}
