package com.example.backend.service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.text.Normalizer;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.Resource;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.config.AccesoDenegadoException;
import com.example.backend.dto.ExportacionResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Asignacion;
import com.example.backend.entity.Carta;
import com.example.backend.entity.Documento;
import com.example.backend.entity.EntidadHistorial;
import com.example.backend.entity.Entrega;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.EstadoEntrega;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.Exportacion;
import com.example.backend.entity.Observacion;
import com.example.backend.entity.Sugerencia;
import com.example.backend.entity.TipoDocumento;
import com.example.backend.entity.TipoExportacion;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.AsignacionRepository;
import com.example.backend.repository.CartaRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.EntregaRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.ExportacionRepository;
import com.example.backend.repository.ObservacionRepository;
import com.example.backend.repository.SugerenciaRepository;
import com.lowagie.text.Chunk;
import com.lowagie.text.Document;
import com.lowagie.text.Element;
import com.lowagie.text.Font;
import com.lowagie.text.FontFactory;
import com.lowagie.text.Image;
import com.lowagie.text.PageSize;
import com.lowagie.text.Paragraph;
import com.lowagie.text.Phrase;
import com.lowagie.text.Rectangle;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;

/**
 * Generación de expedientes PDF y carpetas ZIP (función exclusiva del
 * coordinador, sobre apadrinados y actividades de sus comunidades).
 *
 * 1. PDF de un apadrinado por intervalo de tiempo.
 * 2. PDF de una actividad (solo entregas aprobadas).
 * 3. ZIP de un apadrinado por intervalo (solo entregas aprobadas, la
 *    versión aprobada, una carpeta por actividad).
 * 4. ZIP de una actividad (solo entregas aprobadas, una carpeta por
 *    apadrinado).
 *
 * El intervalo se aplica sobre la fecha de asignación. El archivo
 * generado se guarda temporalmente en el repositorio de documentos y
 * cada generación queda registrada en el historial.
 */
@Service
@RequiredArgsConstructor
@Slf4j
public class ExportacionService {

    private static final DateTimeFormatter FECHA = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter FECHA_HORA = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");
    private static final DateTimeFormatter SELLO = DateTimeFormatter.ofPattern("yyyyMMdd_HHmm");

    private static final Color PRIMARIO = new Color(26, 75, 138);
    private static final Color SECUNDARIO = new Color(70, 80, 95);
    private static final Color FONDO_ENCABEZADO = new Color(235, 242, 250);
    private static final Color FONDO_ALTERNO = new Color(248, 249, 250);
    private static final Color BORDE = new Color(210, 215, 220);

    private static final Font F_TITULO = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 16, PRIMARIO);
    private static final Font F_SUBTITULO = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, SECUNDARIO);
    private static final Font F_SECCION = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, PRIMARIO);
    private static final Font F_ETIQUETA = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.DARK_GRAY);
    private static final Font F_VALOR = FontFactory.getFont(FontFactory.HELVETICA, 9, Color.BLACK);
    private static final Font F_TABLA_CAB = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 8, Color.WHITE);
    private static final Font F_TABLA = FontFactory.getFont(FontFactory.HELVETICA, 8, Color.BLACK);
    private static final Font F_PEQUENA = FontFactory.getFont(FontFactory.HELVETICA_OBLIQUE, 7, Color.GRAY);
    private static final Font F_TEXTO = FontFactory.getFont(FontFactory.HELVETICA, 9, Color.BLACK);

    private final AsignacionRepository asignacionRepository;
    private final EntregaRepository entregaRepository;
    private final DocumentoRepository documentoRepository;
    private final CartaRepository cartaRepository;
    private final SugerenciaRepository sugerenciaRepository;
    private final ObservacionRepository observacionRepository;
    private final ExpedienteRepository expedienteRepository;
    private final ExportacionRepository exportacionRepository;
    private final FileStorageService fileStorageService;
    private final SeguridadService seguridadService;
    private final HistorialActividadService historialService;

    @Value("${app.exportaciones.horas-disponible:24}")
    private int horasDisponible;

    // ==================== 1. PDF DEL APADRINADO ====================

    @Transactional
    public ExportacionResponseDTO pdfApadrinado(Long apadrinadoId, LocalDate desde, LocalDate hasta) {
        validarIntervalo(desde, hasta);
        Apadrinado apadrinado = seguridadService.verificarApadrinadoDeMiComunidad(apadrinadoId);
        Usuario coordinador = seguridadService.usuarioActual();
        List<Asignacion> asignaciones = asignacionesEnIntervalo(apadrinadoId, desde, hasta);
        Expediente expediente = expedienteRepository.findByApadrinadoId(apadrinadoId).orElse(null);
        String nombre = ConvertidorDTO.nombre(apadrinado);

        byte[] pdf = pdf(doc -> {
            encabezado(doc, "Expediente del apadrinado", nombre);

            seccion(doc, "Datos personales");
            Usuario u = apadrinado.getUsuario();
            datos(doc, new String[][] {
                    { "Nombre", nombre },
                    { "Correo", u != null ? u.getCorreo() : null },
                    { "Teléfono", u != null ? u.getTelefono() : null },
                    { "Dirección", u != null ? u.getDireccion() : null },
                    { "Fecha de nacimiento", u != null ? fecha(u.getFechaNacimiento()) : null },
                    { "Código de expediente", expediente != null ? expediente.getCodigo() : null },
            });

            seccion(doc, "Comunidad y coordinador responsable");
            datos(doc, new String[][] {
                    { "Comunidad", apadrinado.getComunidad() != null ? apadrinado.getComunidad().getNombre() : null },
                    { "Municipio", apadrinado.getComunidad() != null ? apadrinado.getComunidad().getMunicipio() : null },
                    { "Coordinador responsable", apadrinado.getCoordinador() != null
                            ? ConvertidorDTO.nombreCompleto(apadrinado.getCoordinador().getUsuario()) : null },
                    { "Intervalo del expediente", intervalo(desde, hasta) },
            });

            seccion(doc, "Actividades asignadas en el intervalo (" + asignaciones.size() + ")");
            if (asignaciones.isEmpty()) {
                doc.add(new Paragraph("No hay actividades asignadas en el intervalo.", F_PEQUENA));
            } else {
                PdfPTable t = tabla(new float[] { 1.3f, 3f, 1.4f, 1.7f, 1.4f, 1.4f },
                        "Tipo", "Actividad", "Fecha límite", "Estado", "Entrega", "Aprobación");
                int fila = 0;
                for (Asignacion s : asignaciones) {
                    Actividad a = s.getActividad();
                    celdas(t, fila++, ActividadService.etiqueta(a.getTipo()), a.getTitulo()
                            + (Boolean.TRUE.equals(a.getEliminada()) ? " (eliminada)" : ""),
                            fecha(a.getFechaLimite()), estado(s.getEstado()), fecha(s.getFechaEnvio()),
                            fecha(s.getFechaAprobacion()));
                }
                doc.add(t);
            }

            // Detalle por actividad: sugerencias, observaciones, cartas, fotos y documentos
            for (Asignacion s : asignaciones) {
                List<Sugerencia> sugerencias = sugerenciaRepository.findByEntregaAsignacionIdOrderByFechaAsc(s.getId());
                List<Observacion> observaciones = observacionRepository.findByAsignacionIdOrderByFechaAsc(s.getId());
                Optional<Entrega> entrega = entregaRepresentativa(s);
                List<Documento> docs = entrega.map(e -> documentoRepository.findByEntregaId(e.getId())).orElse(List.of());
                List<Carta> cartas = entrega.map(e -> cartaRepository.findByEntregaId(e.getId())).orElse(List.of());
                if (sugerencias.isEmpty() && observaciones.isEmpty() && docs.isEmpty() && cartas.isEmpty()) {
                    continue;
                }
                seccion(doc, s.getActividad().getTitulo());
                entrega.ifPresent(e -> doc.add(new Paragraph("Versión " + e.getVersion() + " · "
                        + estadoEntrega(e.getEstado()) + (e.getComentario() != null
                                ? " · Comentario del apadrinado: " + e.getComentario() : ""), F_PEQUENA)));
                if (!sugerencias.isEmpty()) {
                    subtitulo(doc, "Sugerencias de mejora");
                    for (Sugerencia sg : sugerencias) {
                        vineta(doc, "Versión " + sg.getEntrega().getVersion() + " (" + fechaHora(sg.getFecha()) + "): "
                                + sg.getTexto());
                    }
                }
                if (!observaciones.isEmpty()) {
                    subtitulo(doc, "Observaciones");
                    for (Observacion o : observaciones) {
                        vineta(doc, fechaHora(o.getFecha()) + ": " + o.getTexto());
                    }
                }
                cartas(doc, cartas);
                archivos(doc, docs);
            }

            pie(doc, coordinador);
        });
        String archivo = "Expediente_" + carpeta(nombre) + "_" + LocalDateTime.now().format(SELLO) + ".pdf";
        return registrar(TipoExportacion.PDF_APADRINADO, pdf, archivo, "application/pdf",
                apadrinado, null, desde, hasta, coordinador);
    }

    // ==================== 2. PDF DE LA ACTIVIDAD ====================

    @Transactional
    public ExportacionResponseDTO pdfActividad(Long actividadId) {
        Actividad actividad = seguridadService.verificarActividadPropia(actividadId);
        Usuario coordinador = seguridadService.usuarioActual();
        List<Asignacion> asignadas = asignacionRepository.findByActividadIdOrderByApadrinadoUsuarioNombreAsc(actividadId);
        List<Asignacion> aprobadas = aprobadas(actividad, asignadas);

        byte[] pdf = pdf(doc -> {
            encabezado(doc, "Expediente de la actividad", actividad.getTitulo());
            seccion(doc, "Datos de la actividad");
            datos(doc, new String[][] {
                    { "Nombre", actividad.getTitulo() },
                    { "Descripción", actividad.getDescripcion() },
                    { "Instrucciones", actividad.getInstrucciones() },
                    { "Comunidad", actividad.getComunidad() != null ? actividad.getComunidad().getNombre() : null },
                    { "Módulo", actividad.getModulo() != null ? actividad.getModulo().getNombre() : null },
                    { "Fecha límite", fecha(actividad.getFechaLimite()) },
            });

            seccion(doc, "Resumen");
            datos(doc, new String[][] {
                    { "Apadrinados asignados", String.valueOf(asignadas.size()) },
                    { "Entregas aprobadas", String.valueOf(aprobadas.size()) },
            });

            seccion(doc, "Entregas aprobadas");
            for (Asignacion s : aprobadas) {
                Entrega e = entregaAprobada(s).orElseThrow();
                subtitulo(doc, ConvertidorDTO.nombre(s.getApadrinado()));
                doc.add(new Paragraph("Entrega: " + fecha(s.getFechaEnvio()) + "    Aprobación: "
                        + fecha(s.getFechaAprobacion()) + "    Versión aprobada: " + e.getVersion()
                        + (e.getComentario() != null ? "\nComentario: " + e.getComentario() : ""), F_TEXTO));
                cartas(doc, cartaRepository.findByEntregaId(e.getId()));
                archivos(doc, documentoRepository.findByEntregaId(e.getId()));
            }
            pie(doc, coordinador);
        });
        String archivo = "Actividad_" + carpeta(actividad.getTitulo()) + "_" + LocalDateTime.now().format(SELLO) + ".pdf";
        return registrar(TipoExportacion.PDF_ACTIVIDAD, pdf, archivo, "application/pdf",
                null, actividad, null, null, coordinador);
    }

    // ==================== 3. ZIP DEL APADRINADO ====================

    @Transactional
    public ExportacionResponseDTO zipApadrinado(Long apadrinadoId, LocalDate desde, LocalDate hasta) {
        validarIntervalo(desde, hasta);
        Apadrinado apadrinado = seguridadService.verificarApadrinadoDeMiComunidad(apadrinadoId);
        Usuario coordinador = seguridadService.usuarioActual();
        List<Asignacion> aprobadas = asignacionesEnIntervalo(apadrinadoId, desde, hasta).stream()
                .filter(s -> s.getEstado() == EstadoActividad.APROBADO && entregaAprobada(s).isPresent())
                .collect(Collectors.toList());
        if (aprobadas.isEmpty()) {
            throw new RuntimeException("El apadrinado no tiene entregas aprobadas en el intervalo seleccionado.");
        }
        String raiz = carpeta(ConvertidorDTO.nombre(apadrinado));
        byte[] zip = zip(z -> {
            Set<String> usadas = new HashSet<>();
            for (Asignacion s : aprobadas) {
                String dir = raiz + "/" + unico(carpeta(s.getActividad().getTitulo()), usadas) + "/";
                agregarEntrega(z, dir, entregaAprobada(s).orElseThrow());
            }
        });
        String archivo = raiz + "_" + LocalDateTime.now().format(SELLO) + ".zip";
        return registrar(TipoExportacion.ZIP_APADRINADO, zip, archivo, "application/zip",
                apadrinado, null, desde, hasta, coordinador);
    }

    // ==================== 4. ZIP DE LA ACTIVIDAD ====================

    @Transactional
    public ExportacionResponseDTO zipActividad(Long actividadId) {
        Actividad actividad = seguridadService.verificarActividadPropia(actividadId);
        Usuario coordinador = seguridadService.usuarioActual();
        List<Asignacion> aprobadas = aprobadas(actividad,
                asignacionRepository.findByActividadIdOrderByApadrinadoUsuarioNombreAsc(actividadId));
        String raiz = carpeta(actividad.getTitulo());
        byte[] zip = zip(z -> {
            Set<String> usadas = new HashSet<>();
            for (Asignacion s : aprobadas) {
                String dir = raiz + "/" + unico(carpeta(ConvertidorDTO.nombre(s.getApadrinado())), usadas) + "/";
                agregarEntrega(z, dir, entregaAprobada(s).orElseThrow());
            }
        });
        String archivo = raiz + "_" + LocalDateTime.now().format(SELLO) + ".zip";
        return registrar(TipoExportacion.ZIP_ACTIVIDAD, zip, archivo, "application/zip",
                null, actividad, null, null, coordinador);
    }

    // ==================== DESCARGA Y CONSULTA ====================

    @Transactional(readOnly = true)
    public Exportacion obtenerParaDescarga(Long exportacionId) {
        seguridadService.requerirCoordinador();
        Exportacion e = exportacionRepository.findById(exportacionId)
                .orElseThrow(() -> new RuntimeException("Exportación no encontrada con ID: " + exportacionId));
        Usuario usuario = seguridadService.usuarioActual();
        if (e.getGeneradoPor() == null || !e.getGeneradoPor().getId().equals(usuario.getId())) {
            throw new AccesoDenegadoException("Solo puede descargar las exportaciones que usted generó.");
        }
        if (!Boolean.TRUE.equals(e.getDisponible()) || e.getClaveAlmacenamiento() == null) {
            throw new RuntimeException("El archivo ya no está disponible. Genérelo nuevamente.");
        }
        return e;
    }

    public Resource archivo(Exportacion e) {
        return fileStorageService.loadFileAsResource(e.getClaveAlmacenamiento());
    }

    @Transactional(readOnly = true)
    public List<ExportacionResponseDTO> listarMias() {
        seguridadService.requerirCoordinador();
        Usuario usuario = seguridadService.usuarioActual();
        return exportacionRepository.findByGeneradoPorIdOrderByFechaGeneracionDesc(usuario.getId()).stream()
                .map(this::convertir)
                .collect(Collectors.toList());
    }

    /** Los archivos generados se conservan temporalmente; luego se eliminan del repositorio. */
    @Scheduled(cron = "0 15 * * * *")
    @Transactional
    public void limpiarExpiradas() {
        List<Exportacion> vencidas = exportacionRepository.findByDisponibleTrueAndFechaExpiracionBefore(LocalDateTime.now());
        for (Exportacion e : vencidas) {
            fileStorageService.deleteFile(e.getClaveAlmacenamiento());
            e.setDisponible(false);
            e.setClaveAlmacenamiento(null);
        }
        exportacionRepository.saveAll(vencidas);
        if (!vencidas.isEmpty()) {
            log.info("Exportaciones expiradas eliminadas: {}", vencidas.size());
        }
    }

    // ==================== REGISTRO ====================

    private ExportacionResponseDTO registrar(TipoExportacion tipo, byte[] contenido, String nombreArchivo,
            String mime, Apadrinado apadrinado, Actividad actividad, LocalDate desde, LocalDate hasta,
            Usuario usuario) {
        String clave = fileStorageService.storeBytes(contenido, nombreArchivo, mime);
        LocalDateTime ahora = LocalDateTime.now();
        Exportacion e = exportacionRepository.save(Exportacion.builder()
                .tipo(tipo)
                .generadoPor(usuario)
                .apadrinado(apadrinado)
                .actividad(actividad)
                .fechaDesde(desde)
                .fechaHasta(hasta)
                .nombreArchivo(nombreArchivo)
                .claveAlmacenamiento(clave)
                .tipoMime(mime)
                .tamanioBytes((long) contenido.length)
                .fechaGeneracion(ahora)
                .fechaExpiracion(ahora.plusHours(horasDisponible))
                .disponible(true)
                .build());
        String objetivo = apadrinado != null ? "Apadrinado: " + ConvertidorDTO.nombre(apadrinado)
                : "Actividad: " + actividad.getTitulo();
        historialService.registrar(EntidadHistorial.EXPORTACION, e.getId(), nombreArchivo, apadrinado,
                actividad != null ? actividad.getComunidad() : null, actividad,
                "EXPORTACIÓN " + tipo.name().replace('_', ' '),
                objetivo + (apadrinado != null ? " · Intervalo: " + intervalo(desde, hasta) : ""), usuario);
        return convertir(e);
    }

    private ExportacionResponseDTO convertir(Exportacion e) {
        return ExportacionResponseDTO.builder()
                .id(e.getId())
                .tipo(e.getTipo())
                .nombreArchivo(e.getNombreArchivo())
                .tipoMime(e.getTipoMime())
                .tamanioBytes(e.getTamanioBytes())
                .fechaGeneracion(e.getFechaGeneracion())
                .fechaExpiracion(e.getFechaExpiracion())
                .disponible(e.getDisponible())
                .apadrinadoId(e.getApadrinado() != null ? e.getApadrinado().getId() : null)
                .apadrinadoNombre(ConvertidorDTO.nombre(e.getApadrinado()))
                .actividadId(e.getActividad() != null ? e.getActividad().getId() : null)
                .actividadTitulo(e.getActividad() != null ? e.getActividad().getTitulo() : null)
                .fechaDesde(e.getFechaDesde())
                .fechaHasta(e.getFechaHasta())
                .generadoPorNombre(ConvertidorDTO.nombreCompleto(e.getGeneradoPor()))
                .urlDescarga("/api/exportaciones/" + e.getId() + "/descargar")
                .build();
    }

    // ==================== DATOS ====================

    private static void validarIntervalo(LocalDate desde, LocalDate hasta) {
        if (desde != null && hasta != null && desde.isAfter(hasta)) {
            throw new RuntimeException("La fecha de inicio no puede ser posterior a la fecha de fin.");
        }
    }

    /** Asignaciones del apadrinado cuya fecha de asignación está en el intervalo. */
    private List<Asignacion> asignacionesEnIntervalo(Long apadrinadoId, LocalDate desde, LocalDate hasta) {
        LocalDateTime d = desde != null ? desde.atStartOfDay() : LocalDateTime.of(1900, 1, 1, 0, 0);
        LocalDateTime h = hasta != null ? hasta.plusDays(1).atStartOfDay() : LocalDateTime.of(9999, 1, 1, 0, 0);
        return asignacionRepository.findPorApadrinadoEnIntervalo(apadrinadoId, d, h);
    }

    /** Solo tareas con al menos una entrega aprobada. */
    private List<Asignacion> aprobadas(Actividad actividad, List<Asignacion> asignadas) {
        if (!actividad.esTarea()) {
            throw new RuntimeException("Solo las actividades de tipo Tarea tienen entregas para exportar.");
        }
        List<Asignacion> aprobadas = asignadas.stream()
                .filter(s -> s.getEstado() == EstadoActividad.APROBADO && entregaAprobada(s).isPresent())
                .collect(Collectors.toList());
        if (aprobadas.isEmpty()) {
            throw new RuntimeException("La actividad aún no tiene entregas aprobadas.");
        }
        return aprobadas;
    }

    private Optional<Entrega> entregaAprobada(Asignacion s) {
        return entregaRepository.findFirstByAsignacionIdAndEstadoOrderByVersionDesc(s.getId(), EstadoEntrega.APROBADA);
    }

    /** Versión aprobada o, si no existe, la última enviada. */
    private Optional<Entrega> entregaRepresentativa(Asignacion s) {
        Optional<Entrega> aprobada = entregaAprobada(s);
        if (aprobada.isPresent()) {
            return aprobada;
        }
        return entregaRepository.findByAsignacionIdOrderByVersionDesc(s.getId()).stream()
                .filter(e -> e.getEstado() != EstadoEntrega.BORRADOR)
                .findFirst();
    }

    // ==================== PDF ====================

    @FunctionalInterface
    private interface ContenidoPdf {
        void escribir(Document doc) throws Exception;
    }

    @FunctionalInterface
    private interface ContenidoZip {
        void escribir(ZipOutputStream zip) throws Exception;
    }

    private byte[] pdf(ContenidoPdf contenido) {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Document doc = new Document(PageSize.A4, 36, 36, 40, 40);
            PdfWriter.getInstance(doc, out);
            doc.open();
            contenido.escribir(doc);
            doc.close();
            return out.toByteArray();
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("No se pudo generar el PDF: " + e.getMessage(), e);
        }
    }

    private void encabezado(Document doc, String titulo, String subtitulo) {
        PdfPTable t = new PdfPTable(1);
        t.setWidthPercentage(100);
        t.setSpacingAfter(12);
        PdfPCell c = new PdfPCell();
        c.setBackgroundColor(FONDO_ENCABEZADO);
        c.setBorderColor(BORDE);
        c.setPadding(10);
        Paragraph p = new Paragraph();
        p.add(new Chunk("UNBOARD · Fundación UNBOUND, sede Huehuetenango\n", F_PEQUENA));
        p.add(new Chunk(titulo + "\n", F_TITULO));
        p.add(new Chunk(subtitulo != null ? subtitulo : "", F_SUBTITULO));
        c.addElement(p);
        t.addCell(c);
        doc.add(t);
    }

    private void seccion(Document doc, String titulo) {
        Paragraph p = new Paragraph(titulo, F_SECCION);
        p.setSpacingBefore(10);
        p.setSpacingAfter(5);
        doc.add(p);
    }

    private void subtitulo(Document doc, String texto) {
        Paragraph p = new Paragraph(texto, F_ETIQUETA);
        p.setSpacingBefore(5);
        p.setSpacingAfter(2);
        doc.add(p);
    }

    private void vineta(Document doc, String texto) {
        Paragraph p = new Paragraph("• " + texto, F_TEXTO);
        p.setIndentationLeft(8);
        doc.add(p);
    }

    private void datos(Document doc, String[][] filas) {
        PdfPTable t = new PdfPTable(new float[] { 1.3f, 3.7f });
        t.setWidthPercentage(100);
        for (String[] fila : filas) {
            PdfPCell et = new PdfPCell(new Phrase(fila[0], F_ETIQUETA));
            et.setBorder(Rectangle.BOTTOM);
            et.setBorderColor(BORDE);
            et.setPadding(4);
            PdfPCell va = new PdfPCell(new Phrase(fila[1] != null && !fila[1].isBlank() ? fila[1] : "—", F_VALOR));
            va.setBorder(Rectangle.BOTTOM);
            va.setBorderColor(BORDE);
            va.setPadding(4);
            t.addCell(et);
            t.addCell(va);
        }
        doc.add(t);
    }

    private PdfPTable tabla(float[] anchos, String... cabeceras) {
        PdfPTable t = new PdfPTable(anchos);
        t.setWidthPercentage(100);
        t.setHeaderRows(1);
        for (String c : cabeceras) {
            PdfPCell cell = new PdfPCell(new Phrase(c, F_TABLA_CAB));
            cell.setBackgroundColor(PRIMARIO);
            cell.setBorderColor(BORDE);
            cell.setPadding(4);
            t.addCell(cell);
        }
        return t;
    }

    private void celdas(PdfPTable t, int fila, String... valores) {
        for (String v : valores) {
            PdfPCell cell = new PdfPCell(new Phrase(v != null && !v.isBlank() ? v : "—", F_TABLA));
            cell.setBorderColor(BORDE);
            cell.setPadding(4);
            if (fila % 2 == 1) {
                cell.setBackgroundColor(FONDO_ALTERNO);
            }
            t.addCell(cell);
        }
    }

    private void cartas(Document doc, List<Carta> cartas) {
        if (cartas.isEmpty()) {
            return;
        }
        subtitulo(doc, "Cartas escritas por el apadrinado");
        for (Carta c : cartas) {
            PdfPTable t = new PdfPTable(1);
            t.setWidthPercentage(100);
            t.setSpacingAfter(4);
            PdfPCell cell = new PdfPCell();
            cell.setBorderColor(BORDE);
            cell.setPadding(6);
            cell.addElement(new Paragraph(c.getTitulo(), F_ETIQUETA));
            cell.addElement(new Paragraph(c.getContenido(), F_TEXTO));
            t.addCell(cell);
            doc.add(t);
        }
    }

    /** Fotografías en miniatura y lista de los demás documentos entregados. */
    private void archivos(Document doc, List<Documento> docs) {
        List<Documento> fotos = docs.stream()
                .filter(d -> d.getTipoDocumento() == TipoDocumento.FOTOGRAFIA)
                .collect(Collectors.toList());
        List<Documento> otros = docs.stream()
                .filter(d -> d.getTipoDocumento() != TipoDocumento.FOTOGRAFIA)
                .collect(Collectors.toList());
        if (!fotos.isEmpty()) {
            subtitulo(doc, "Fotografías entregadas");
            PdfPTable t = new PdfPTable(4);
            t.setWidthPercentage(100);
            for (Documento f : fotos) {
                PdfPCell cell = new PdfPCell();
                cell.setBorderColor(BORDE);
                cell.setPadding(3);
                cell.setHorizontalAlignment(Element.ALIGN_CENTER);
                try {
                    Image img = Image.getInstance(fileStorageService.readBytes(f.getNombreAlmacenado()));
                    img.scaleToFit(110, 90);
                    cell.addElement(img);
                } catch (Exception e) {
                    cell.addElement(new Paragraph("(vista previa no disponible)", F_PEQUENA));
                }
                cell.addElement(new Paragraph(f.getNombreOriginal(), F_PEQUENA));
                t.addCell(cell);
            }
            t.completeRow();
            doc.add(t);
        }
        if (!otros.isEmpty()) {
            subtitulo(doc, "Documentos entregados");
            for (Documento d : otros) {
                vineta(doc, d.getNombreOriginal() + " (" + tipoDocumento(d.getTipoDocumento()) + ")"
                        + (d.getDescripcion() != null ? " — " + d.getDescripcion() : ""));
            }
        }
    }

    private void pie(Document doc, Usuario coordinador) {
        Paragraph p = new Paragraph("Generado el " + LocalDateTime.now().format(FECHA_HORA) + " por "
                + ConvertidorDTO.nombreCompleto(coordinador) + " (coordinador).", F_PEQUENA);
        p.setSpacingBefore(14);
        p.setAlignment(Element.ALIGN_RIGHT);
        doc.add(p);
    }

    // ==================== ZIP ====================

    private byte[] zip(ContenidoZip contenido) {
        try (ByteArrayOutputStream out = new ByteArrayOutputStream();
                ZipOutputStream zip = new ZipOutputStream(out, StandardCharsets.UTF_8)) {
            contenido.escribir(zip);
            zip.finish();
            return out.toByteArray();
        } catch (RuntimeException e) {
            throw e;
        } catch (Exception e) {
            throw new RuntimeException("No se pudo generar el ZIP: " + e.getMessage(), e);
        }
    }

    /** Archivos y cartas de la versión aprobada de la entrega. */
    private void agregarEntrega(ZipOutputStream zip, String dir, Entrega entrega) throws IOException {
        zip.putNextEntry(new ZipEntry(dir));
        zip.closeEntry();
        Set<String> usados = new HashSet<>();
        for (Documento d : documentoRepository.findByEntregaId(entrega.getId())) {
            try {
                byte[] datos = fileStorageService.readBytes(d.getNombreAlmacenado());
                zip.putNextEntry(new ZipEntry(dir + unico(archivo(d.getNombreOriginal()), usados)));
                zip.write(datos);
                zip.closeEntry();
            } catch (RuntimeException e) {
                log.warn("Archivo omitido en el ZIP ({}): {}", d.getNombreOriginal(), e.getMessage());
            }
        }
        int n = 1;
        for (Carta c : cartaRepository.findByEntregaId(entrega.getId())) {
            String texto = c.getTitulo() + "\n\n" + c.getContenido() + "\n";
            zip.putNextEntry(new ZipEntry(dir + unico("Carta_" + (n++) + ".txt", usados)));
            zip.write(texto.getBytes(StandardCharsets.UTF_8));
            zip.closeEntry();
        }
        if (entrega.getComentario() != null) {
            zip.putNextEntry(new ZipEntry(dir + unico("Comentario.txt", usados)));
            zip.write(entrega.getComentario().getBytes(StandardCharsets.UTF_8));
            zip.closeEntry();
        }
    }

    // ==================== FORMATO ====================

    /** Nombre de carpeta seguro: sin acentos ni caracteres especiales. */
    static String carpeta(String texto) {
        if (texto == null || texto.isBlank()) {
            return "Sin_nombre";
        }
        String s = Normalizer.normalize(texto.trim(), Normalizer.Form.NFD).replaceAll("\\p{M}", "");
        s = s.replaceAll("[^A-Za-z0-9]+", "_").replaceAll("^_+|_+$", "");
        if (s.length() > 60) {
            s = s.substring(0, 60);
        }
        return s.isEmpty() ? "Sin_nombre" : s;
    }

    private static String archivo(String nombre) {
        if (nombre == null || nombre.isBlank()) {
            return "archivo";
        }
        int punto = nombre.lastIndexOf('.');
        String base = punto > 0 ? nombre.substring(0, punto) : nombre;
        String ext = punto > 0 ? nombre.substring(punto).toLowerCase().replaceAll("[^.a-z0-9]", "") : "";
        return carpeta(base) + ext;
    }

    private static String unico(String nombre, Set<String> usados) {
        String candidato = nombre;
        int i = 2;
        while (!usados.add(candidato.toLowerCase())) {
            int punto = nombre.lastIndexOf('.');
            candidato = punto > 0
                    ? nombre.substring(0, punto) + "_" + i + nombre.substring(punto)
                    : nombre + "_" + i;
            i++;
        }
        return candidato;
    }

    private static String fecha(LocalDate f) {
        return f != null ? f.format(FECHA) : null;
    }

    private static String fecha(LocalDateTime f) {
        return f != null ? f.format(FECHA) : null;
    }

    private static String fechaHora(LocalDateTime f) {
        return f != null ? f.format(FECHA_HORA) : "—";
    }

    private static String intervalo(LocalDate desde, LocalDate hasta) {
        if (desde == null && hasta == null) {
            return "Todo el historial";
        }
        return (desde != null ? fecha(desde) : "inicio") + " al " + (hasta != null ? fecha(hasta) : "hoy");
    }

    static String estado(EstadoActividad e) {
        if (e == null) {
            return null;
        }
        return switch (e) {
            case PENDIENTE -> "Pendiente";
            case EN_PROGRESO -> "En progreso";
            case ENVIADO -> "Enviado";
            case EN_REVISION -> "En revisión";
            case CORRECCION_SOLICITADA -> "Corrección solicitada";
            case APROBADO -> "Aprobado";
            case VENCIDO -> "Vencido";
            case PUBLICADO -> "Publicado";
            case VISTO -> "Visto";
        };
    }

    private static String estadoEntrega(EstadoEntrega e) {
        return switch (e) {
            case BORRADOR -> "Borrador";
            case ENVIADA -> "Enviada";
            case EN_REVISION -> "En revisión";
            case CORRECCION_SOLICITADA -> "Corrección solicitada";
            case APROBADA -> "Aprobada";
        };
    }

    private static String tipoDocumento(TipoDocumento t) {
        return switch (t) {
            case DOCUMENTO -> "Documento";
            case CARTA -> "Carta";
            case FOTOGRAFIA -> "Fotografía";
            case FORMULARIO -> "Formulario";
            case EVIDENCIA -> "Evidencia";
            case MATERIAL -> "Material";
            default -> "Otro";
        };
    }

    static <T> List<T> ordenar(List<T> lista, Comparator<T> c) {
        List<T> copia = new ArrayList<>(lista);
        copia.sort(c);
        return copia;
    }
}
