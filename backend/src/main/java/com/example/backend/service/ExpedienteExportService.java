package com.example.backend.service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.ActividadComunidadResumenDTO;
import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.ApadrinadoResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.ExpedienteResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.entity.Actividad;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Comunidad;
import com.example.backend.entity.Documento;
import com.example.backend.entity.EstadoActividad;
import com.example.backend.entity.Expediente;
import com.example.backend.entity.HistorialActividad;
import com.example.backend.entity.Usuario;
import com.example.backend.repository.ActividadRepository;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.ComunidadRepository;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;
import com.example.backend.repository.HistorialActividadRepository;
import com.lowagie.text.Chunk;
import com.lowagie.text.Document;
import com.lowagie.text.Element;
import com.lowagie.text.Font;
import com.lowagie.text.FontFactory;
import com.lowagie.text.PageSize;
import com.lowagie.text.Paragraph;
import com.lowagie.text.Phrase;
import com.lowagie.text.Rectangle;
import com.lowagie.text.pdf.PdfPCell;
import com.lowagie.text.pdf.PdfPTable;
import com.lowagie.text.pdf.PdfWriter;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ExpedienteExportService {

    private final ExpedienteRepository expedienteRepository;
    private final DocumentoRepository documentoRepository;
    private final ActividadRepository actividadRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final ComunidadRepository comunidadRepository;
    private final HistorialActividadRepository historialActividadRepository;
    private final ExpedienteService expedienteService;
    private final FileStorageService fileStorageService;
    private final HistorialActividadService historialActividadService;

    private static final DateTimeFormatter DATE_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
    private static final DateTimeFormatter DATETIME_FMT = DateTimeFormatter.ofPattern("dd/MM/yyyy HH:mm");

    // Colores del diseño
    private static final Color COLOR_PRIMARY = new Color(26, 75, 138); // Azul institucional
    private static final Color COLOR_SECONDARY = new Color(70, 80, 95);
    private static final Color COLOR_BG_HEADER = new Color(235, 242, 250);
    private static final Color COLOR_BG_ALT = new Color(248, 249, 250);
    private static final Color COLOR_BORDER = new Color(210, 215, 220);

    public byte[] generarPdfConsolidado(Long expedienteId) {
        return generarPdfConsolidado(expedienteId, null, null);
    }

    /**
     * Genera el PDF consolidado del expediente. Cuando se indica un
     * intervalo [desde, hasta], solo se incluyen las actividades con
     * fecha límite, los documentos con fecha de subida y los registros
     * de la bitácora con fecha/hora dentro del período.
     */
    @Transactional(readOnly = true)
    public byte[] generarPdfConsolidado(Long expedienteId, LocalDate desde, LocalDate hasta) {
        validarIntervalo(desde, hasta);
        Expediente expediente = expedienteRepository.findById(expedienteId)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + expedienteId));

        ExpedienteResponseDTO dto = expedienteService.convertirAResponseDTO(expediente, true);
        ApadrinadoResponseDTO apadrinado = dto.getApadrinado();
        List<ActividadResponseDTO> actividades = dto.getActividades();
        List<DocumentoResponseDTO> documentos = dto.getDocumentos();

        // ==================== FILTRO POR INTERVALO ====================
        final LocalDateTime desdeDt = desde != null ? desde.atStartOfDay() : null;
        final LocalDateTime hastaDt = hasta != null ? hasta.atTime(LocalTime.MAX) : null;
        final boolean conFiltro = desde != null || hasta != null;

        if (conFiltro) {
            if (actividades != null) {
                actividades = actividades.stream()
                        .filter(a -> enIntervaloFecha(a.getFechaLimite(), desde, hasta))
                        .collect(Collectors.toList());
            }
            if (documentos != null) {
                documentos = documentos.stream()
                        .filter(d -> enIntervaloFechaHora(d.getFechaSubida(), desdeDt, hastaDt))
                        .collect(Collectors.toList());
            }
        }

        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Document document = new Document(PageSize.A4, 36, 36, 40, 40);
            PdfWriter.getInstance(document, out);
            document.open();

            // Fuentes
            Font fontHeaderTitle = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 16, COLOR_PRIMARY);
            Font fontHeaderSubtitle = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 12, COLOR_SECONDARY);
            Font fontSectionTitle = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, COLOR_PRIMARY);
            Font fontLabel = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.DARK_GRAY);
            Font fontValue = FontFactory.getFont(FontFactory.HELVETICA, 9, Color.BLACK);
            Font fontTableHead = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 8, Color.WHITE);
            Font fontTableBody = FontFactory.getFont(FontFactory.HELVETICA, 8, Color.BLACK);
            Font fontSmall = FontFactory.getFont(FontFactory.HELVETICA_OBLIQUE, 7, Color.GRAY);

            // ==================== ENCABEZADO ====================
            PdfPTable headerTable = new PdfPTable(1);
            headerTable.setWidthPercentage(100);
            headerTable.setSpacingAfter(15);

            PdfPCell headerCell = new PdfPCell();
            headerCell.setBorder(Rectangle.BOTTOM);
            headerCell.setBorderColor(COLOR_PRIMARY);
            headerCell.setBorderWidth(2);
            headerCell.setPaddingBottom(8);

            Paragraph pOrg = new Paragraph("FUNDACIÓN UNBOUND - SEDE HUEHUETENANGO", fontHeaderTitle);
            pOrg.setAlignment(Element.ALIGN_CENTER);
            headerCell.addElement(pOrg);

            Paragraph pSub = new Paragraph("EXPEDIENTE DIGITAL DEL BENEFICIARIO", fontHeaderSubtitle);
            pSub.setAlignment(Element.ALIGN_CENTER);
            headerCell.addElement(pSub);

            String meta = "Expediente #" + dto.getId() + " | Fecha de Generación: " + java.time.LocalDate.now().format(DATE_FMT);
            if (conFiltro) {
                meta += " | Período: "
                        + (desde != null ? desde.format(DATE_FMT) : "...") + " - "
                        + (hasta != null ? hasta.format(DATE_FMT) : "...");
            }
            Paragraph pMeta = new Paragraph(meta, fontSmall);
            pMeta.setAlignment(Element.ALIGN_CENTER);
            headerCell.addElement(pMeta);

            headerTable.addCell(headerCell);
            document.add(headerTable);

            // ==================== SECCIÓN 1: DATOS DEL BENEFICIARIO ====================
            Paragraph sec1 = new Paragraph("1. DATOS GENERALES DEL APADRINADO", fontSectionTitle);
            sec1.setSpacingAfter(6);
            document.add(sec1);

            PdfPTable infoTable = new PdfPTable(4);
            infoTable.setWidthPercentage(100);
            infoTable.setWidths(new float[]{25, 25, 25, 25});
            infoTable.setSpacingAfter(15);

            agregarCeldaInfo(infoTable, "Nombre Beneficiario:", apadrinado != null && apadrinado.getNombre() != null ? apadrinado.getNombre() : "N/A", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Correo:", apadrinado != null && apadrinado.getCorreo() != null ? apadrinado.getCorreo() : "N/A", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Comunidad:", apadrinado != null && apadrinado.getComunidadNombre() != null ? apadrinado.getComunidadNombre() : "No asignada", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Coordinador:", apadrinado != null && apadrinado.getCoordinadorNombre() != null ? apadrinado.getCoordinadorNombre() : "No asignado", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Fecha Creación:", dto.getFechaCreacion() != null ? dto.getFechaCreacion().format(DATE_FMT) : "N/A", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Total Actividades:", String.valueOf(actividades != null ? actividades.size() : 0), fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Total Documentos:", String.valueOf(documentos != null ? documentos.size() : 0), fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Estado Expediente:", "ACTIVO", fontLabel, fontValue);

            document.add(infoTable);

            // ==================== SECCIÓN 2: HISTORIAL DE ACTIVIDADES ====================
            Paragraph sec2 = new Paragraph("2. SEGUIMIENTO DE ACTIVIDADES (" + (actividades != null ? actividades.size() : 0) + ")", fontSectionTitle);
            sec2.setSpacingAfter(6);
            document.add(sec2);

            PdfPTable actTable = new PdfPTable(5);
            actTable.setWidthPercentage(100);
            actTable.setWidths(new float[]{30, 15, 15, 18, 22});
            actTable.setSpacingAfter(15);

            // Header tabla actividades
            agregarCeldaCabecera(actTable, "Actividad / Título", fontTableHead);
            agregarCeldaCabecera(actTable, "Fecha Límite", fontTableHead);
            agregarCeldaCabecera(actTable, "Requisitos", fontTableHead);
            agregarCeldaCabecera(actTable, "Estado", fontTableHead);
            agregarCeldaCabecera(actTable, "Observaciones", fontTableHead);

            if (actividades != null && !actividades.isEmpty()) {
                boolean alt = false;
                for (ActividadResponseDTO act : actividades) {
                    Color bg = alt ? COLOR_BG_ALT : Color.WHITE;
                    alt = !alt;

                    agregarCeldaCuerpo(actTable, act.getTitulo() != null ? act.getTitulo() : "-", fontTableBody, bg);
                    agregarCeldaCuerpo(actTable, act.getFechaLimite() != null ? act.getFechaLimite().format(DATE_FMT) : "-", fontTableBody, bg);
                    
                    String reqs = (Boolean.TRUE.equals(act.getRequiereFotografia()) ? "Foto " : "") + (Boolean.TRUE.equals(act.getRequiereDocumento()) ? "Doc" : "");
                    if (reqs.isBlank()) reqs = "Ninguno";
                    agregarCeldaCuerpo(actTable, reqs, fontTableBody, bg);

                    String estadoStr = act.getEstado() != null ? act.getEstado().name() : "PENDIENTE";
                    agregarCeldaCuerpo(actTable, estadoStr, fontTableBody, bg);
                    agregarCeldaCuerpo(actTable, act.getObservaciones() != null ? act.getObservaciones() : "-", fontTableBody, bg);
                }
            } else {
                PdfPCell vacio = new PdfPCell(new Phrase("No hay actividades registradas en este expediente.", fontTableBody));
                vacio.setColspan(5);
                vacio.setPadding(8);
                vacio.setHorizontalAlignment(Element.ALIGN_CENTER);
                actTable.addCell(vacio);
            }
            document.add(actTable);

            // ==================== SECCIÓN 3: INVENTARIO DOCUMENTAL ====================
            Paragraph sec3 = new Paragraph("3. INVENTARIO DE DOCUMENTOS Y EVIDENCIAS (" + (documentos != null ? documentos.size() : 0) + ")", fontSectionTitle);
            sec3.setSpacingAfter(6);
            document.add(sec3);

            PdfPTable docTable = new PdfPTable(5);
            docTable.setWidthPercentage(100);
            docTable.setWidths(new float[]{18, 32, 18, 14, 18});
            docTable.setSpacingAfter(20);

            agregarCeldaCabecera(docTable, "Tipo", fontTableHead);
            agregarCeldaCabecera(docTable, "Nombre Archivo", fontTableHead);
            agregarCeldaCabecera(docTable, "Fecha Subida", fontTableHead);
            agregarCeldaCabecera(docTable, "Tamaño", fontTableHead);
            agregarCeldaCabecera(docTable, "Actividad Asociada", fontTableHead);

            if (documentos != null && !documentos.isEmpty()) {
                boolean alt = false;
                for (DocumentoResponseDTO doc : documentos) {
                    Color bg = alt ? COLOR_BG_ALT : Color.WHITE;
                    alt = !alt;

                    agregarCeldaCuerpo(docTable, doc.getTipoDocumento() != null ? doc.getTipoDocumento().name() : "OTRO", fontTableBody, bg);
                    agregarCeldaCuerpo(docTable, doc.getNombreOriginal() != null ? doc.getNombreOriginal() : "-", fontTableBody, bg);
                    agregarCeldaCuerpo(docTable, doc.getFechaSubida() != null ? doc.getFechaSubida().format(DATETIME_FMT) : "-", fontTableBody, bg);
                    
                    String tamanioStr = "-";
                    if (doc.getTamanioBytes() != null) {
                        tamanioStr = String.format("%.1f KB", doc.getTamanioBytes() / 1024.0);
                    }
                    agregarCeldaCuerpo(docTable, tamanioStr, fontTableBody, bg);
                    agregarCeldaCuerpo(docTable, doc.getActividadTitulo() != null ? doc.getActividadTitulo() : "General", fontTableBody, bg);
                }
            } else {
                PdfPCell vacio = new PdfPCell(new Phrase("No hay documentos subidos en este expediente.", fontTableBody));
                vacio.setColspan(5);
                vacio.setPadding(8);
                vacio.setHorizontalAlignment(Element.ALIGN_CENTER);
                docTable.addCell(vacio);
            }
            document.add(docTable);

            // ==================== SECCIÓN 4: BITÁCORA Y TRAZABILIDAD ====================
            List<HistorialActividadResponseDTO> historial = (apadrinado != null && apadrinado.getId() != null)
                    ? historialActividadService.listarPorApadrinado(apadrinado.getId())
                    : List.of();

            if (conFiltro) {
                historial = historial.stream()
                        .filter(h -> enIntervaloFechaHora(h.getFechaHora(), desdeDt, hastaDt))
                        .collect(Collectors.toList());
            }

            Paragraph sec4 = new Paragraph("4. BITÁCORA DE CAMBIOS Y TRAZABILIDAD (" + historial.size() + ")", fontSectionTitle);
            sec4.setSpacingAfter(6);
            document.add(sec4);

            PdfPTable histTable = new PdfPTable(5);
            histTable.setWidthPercentage(100);
            histTable.setWidths(new float[]{18, 25, 20, 17, 20});
            histTable.setSpacingAfter(15);

            agregarCeldaCabecera(histTable, "Fecha/Hora", fontTableHead);
            agregarCeldaCabecera(histTable, "Actividad", fontTableHead);
            agregarCeldaCabecera(histTable, "Acción", fontTableHead);
            agregarCeldaCabecera(histTable, "Estado", fontTableHead);
            agregarCeldaCabecera(histTable, "Modificado Por", fontTableHead);

            if (!historial.isEmpty()) {
                boolean alt = false;
                for (HistorialActividadResponseDTO h : historial) {
                    Color bg = alt ? COLOR_BG_ALT : Color.WHITE;
                    alt = !alt;

                    agregarCeldaCuerpo(histTable, h.getFechaHora() != null ? h.getFechaHora().format(DATETIME_FMT) : "-", fontTableBody, bg);
                    agregarCeldaCuerpo(histTable, h.getActividadTitulo() != null ? h.getActividadTitulo() : "-", fontTableBody, bg);
                    agregarCeldaCuerpo(histTable, h.getAccion() != null ? h.getAccion() : "-", fontTableBody, bg);
                    agregarCeldaCuerpo(histTable, h.getEstadoNuevo() != null ? h.getEstadoNuevo().name() : "-", fontTableBody, bg);
                    String modPor = (h.getModificadoPorNombre() != null ? h.getModificadoPorNombre() : "Sistema")
                            + (h.getModificadoPorRol() != null ? " (" + h.getModificadoPorRol() + ")" : "");
                    agregarCeldaCuerpo(histTable, modPor, fontTableBody, bg);
                }
            } else {
                PdfPCell vacio = new PdfPCell(new Phrase("No hay registros de cambios en la bitácora.", fontTableBody));
                vacio.setColspan(5);
                vacio.setPadding(8);
                vacio.setHorizontalAlignment(Element.ALIGN_CENTER);
                histTable.addCell(vacio);
            }
            document.add(histTable);

            // ==================== PIE DE PÁGINA ====================
            Paragraph pFooter = new Paragraph("Este documento es una copia oficial generada por el Sistema de Gestión Documental de la Fundación UNBOUND Huehuetenango.", fontSmall);
            pFooter.setAlignment(Element.ALIGN_CENTER);
            pFooter.setSpacingBefore(10);
            document.add(pFooter);

            document.close();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new RuntimeException("Error al generar el reporte PDF del expediente: " + ex.getMessage(), ex);
        }
    }

    public byte[] generarZipOrganizado(Long expedienteId) {
        return generarZipOrganizado(expedienteId, null, null);
    }

    /**
     * Genera el ZIP organizado del expediente. Con un intervalo
     * [desde, hasta] solo se incluyen los documentos subidos en
     * ese período (el PDF consolidado respeta el mismo filtro).
     */
    @Transactional(readOnly = true)
    public byte[] generarZipOrganizado(Long expedienteId, LocalDate desde, LocalDate hasta) {
        validarIntervalo(desde, hasta);
        Expediente expediente = expedienteRepository.findById(expedienteId)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + expedienteId));

        ExpedienteResponseDTO dto = expedienteService.convertirAResponseDTO(expediente, true);
        List<Documento> documentos = documentoRepository.findByExpedienteId(expedienteId);

        if (desde != null || hasta != null) {
            final LocalDateTime desdeDt = desde != null ? desde.atStartOfDay() : null;
            final LocalDateTime hastaDt = hasta != null ? hasta.atTime(LocalTime.MAX) : null;
            documentos = documentos.stream()
                    .filter(d -> enIntervaloFechaHora(d.getFechaSubida(), desdeDt, hastaDt))
                    .collect(Collectors.toList());
        }

        try (ByteArrayOutputStream out = new ByteArrayOutputStream();
             ZipOutputStream zipOut = new ZipOutputStream(out)) {

            // 1. Incluir el PDF consolidado del expediente dentro del ZIP
            byte[] pdfBytes = generarPdfConsolidado(expedienteId, desde, hasta);
            ZipEntry pdfEntry = new ZipEntry("Reporte_Expediente_" + expedienteId + ".pdf");
            zipOut.putNextEntry(pdfEntry);
            zipOut.write(pdfBytes);
            zipOut.closeEntry();

            // 2. Incluir archivo de texto con resumen del expediente
            StringBuilder resumen = new StringBuilder();
            resumen.append("====================================================\n");
            resumen.append("FUNDACIÓN UNBOUND - SEDE HUEHUETENANGO\n");
            resumen.append("RESUMEN DE EXPEDIENTE DIGITAL #").append(expedienteId).append("\n");
            resumen.append("====================================================\n\n");
            if (dto.getApadrinado() != null) {
                resumen.append("Beneficiario: ").append(dto.getApadrinado().getNombre()).append("\n");
                resumen.append("Correo: ").append(dto.getApadrinado().getCorreo()).append("\n");
                resumen.append("Comunidad: ").append(dto.getApadrinado().getComunidadNombre()).append("\n");
                resumen.append("Coordinador: ").append(dto.getApadrinado().getCoordinadorNombre()).append("\n");
            }
            resumen.append("Fecha Creación: ").append(dto.getFechaCreacion()).append("\n");
            if (desde != null || hasta != null) {
                resumen.append("Período: ").append(desde != null ? desde : "...")
                        .append(" - ").append(hasta != null ? hasta : "...").append("\n");
            }
            resumen.append("Total Documentos: ").append(documentos.size()).append("\n");
            resumen.append("Total Actividades: ").append(dto.getTotalActividades()).append("\n\n");
            resumen.append("Estructura de Carpetas:\n");
            resumen.append("- 1_Cartas/\n");
            resumen.append("- 2_Fotografias/\n");
            resumen.append("- 3_Formularios/\n");
            resumen.append("- 4_Evidencias/\n");
            resumen.append("- 5_Otros/\n");

            ZipEntry infoEntry = new ZipEntry("informacion_expediente.txt");
            zipOut.putNextEntry(infoEntry);
            zipOut.write(resumen.toString().getBytes(StandardCharsets.UTF_8));
            zipOut.closeEntry();

            // 3. Organizar y añadir cada documento en su carpeta correspondiente
            for (Documento doc : documentos) {
                String subCarpeta = switch (doc.getTipoDocumento() != null ? doc.getTipoDocumento() : com.example.backend.entity.TipoDocumento.OTRO) {
                    case CARTA -> "1_Cartas/";
                    case FOTOGRAFIA -> "2_Fotografias/";
                    case FORMULARIO -> "3_Formularios/";
                    case EVIDENCIA -> "4_Evidencias/";
                    default -> "5_Otros/";
                };

                String nombreArchivo = doc.getId() + "_" + (doc.getNombreOriginal() != null ? doc.getNombreOriginal() : "documento");
                agregarDocumentoAlZip(zipOut, subCarpeta + nombreArchivo, doc);
            }

            zipOut.finish();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new RuntimeException("Error al generar el archivo ZIP del expediente: " + ex.getMessage(), ex);
        }
    }

    // ==================== EXPEDIENTE DE ACTIVIDAD ====================

    /**
     * Lista las operaciones de actividad de una comunidad (creación
     * masiva = una fila de Actividad por apadrinado con mismo título y
     * fecha de creación), con el conteo de asignadas y aprobadas.
     */
    @Transactional(readOnly = true)
    public List<ActividadComunidadResumenDTO> listarActividadesPorComunidad(Long comunidadId) {
        Comunidad comunidad = comunidadRepository.findById(comunidadId)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + comunidadId));

        Map<String, List<Actividad>> grupos = actividadRepository.findByApadrinadoComunidadId(comunidadId)
                .stream()
                .collect(Collectors.groupingBy(this::claveOperacion, LinkedHashMap::new, Collectors.toList()));

        return grupos.values().stream()
                .map(grupo -> {
                    Actividad ref = grupo.get(0);
                    return ActividadComunidadResumenDTO.builder()
                            .actividadId(ref.getId())
                            .titulo(ref.getTitulo())
                            .fechaCreacion(ref.getFechaCreacion())
                            .fechaLimite(ref.getFechaLimite())
                            .comunidadId(comunidad.getId())
                            .comunidadNombre(comunidad.getNombre())
                            .totalAsignadas(grupo.size())
                            .totalAprobadas((int) grupo.stream()
                                    .filter(a -> a.getEstado() == EstadoActividad.APROBADA)
                                    .count())
                            .build();
                })
                .sorted(Comparator.comparing(ActividadComunidadResumenDTO::getFechaCreacion,
                        Comparator.nullsLast(Comparator.reverseOrder())))
                .collect(Collectors.toList());
    }

    /**
     * Resuelve la comunidad del expediente de actividad: la indicada o,
     * si no se indica, la del apadrinado de la actividad de referencia.
     */
    @Transactional(readOnly = true)
    public Long resolverComunidadActividad(Long actividadId, Long comunidadId) {
        if (comunidadId != null) {
            return comunidadId;
        }
        Actividad ref = actividadRepository.findById(actividadId)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + actividadId));
        if (ref.getApadrinado() == null || ref.getApadrinado().getComunidad() == null) {
            throw new IllegalArgumentException("La actividad no está asociada a ninguna comunidad.");
        }
        return ref.getApadrinado().getComunidad().getId();
    }

    /**
     * Genera el expediente de actividad: PDF que consolida una misma
     * operación con los apadrinados de la comunidad, su estado, la
     * última acción registrada y las evidencias entregadas. Con
     * {@code soloAprobadas} solo se incluyen las entregas aprobadas.
     */
    @Transactional(readOnly = true)
    public byte[] generarPdfActividad(Long actividadId, Long comunidadId, boolean soloAprobadas) {
        OperacionActividad op = cargarOperacion(actividadId, comunidadId, soloAprobadas);
        Actividad ref = op.referencia();

        try (ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            Document document = new Document(PageSize.A4, 36, 36, 40, 40);
            PdfWriter.getInstance(document, out);
            document.open();

            Font fontHeaderTitle = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 16, COLOR_PRIMARY);
            Font fontHeaderSubtitle = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 12, COLOR_SECONDARY);
            Font fontSectionTitle = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, COLOR_PRIMARY);
            Font fontLabel = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 9, Color.DARK_GRAY);
            Font fontValue = FontFactory.getFont(FontFactory.HELVETICA, 9, Color.BLACK);
            Font fontTableHead = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 8, Color.WHITE);
            Font fontTableBody = FontFactory.getFont(FontFactory.HELVETICA, 8, Color.BLACK);
            Font fontSmall = FontFactory.getFont(FontFactory.HELVETICA_OBLIQUE, 7, Color.GRAY);

            // ==================== ENCABEZADO ====================
            PdfPTable headerTable = new PdfPTable(1);
            headerTable.setWidthPercentage(100);
            headerTable.setSpacingAfter(15);

            PdfPCell headerCell = new PdfPCell();
            headerCell.setBorder(Rectangle.BOTTOM);
            headerCell.setBorderColor(COLOR_PRIMARY);
            headerCell.setBorderWidth(2);
            headerCell.setPaddingBottom(8);

            Paragraph pOrg = new Paragraph("FUNDACIÓN UNBOUND - SEDE HUEHUETENANGO", fontHeaderTitle);
            pOrg.setAlignment(Element.ALIGN_CENTER);
            headerCell.addElement(pOrg);

            Paragraph pSub = new Paragraph(soloAprobadas
                    ? "EXPEDIENTE DE ACTIVIDAD - ENTREGAS APROBADAS"
                    : "EXPEDIENTE DE ACTIVIDAD", fontHeaderSubtitle);
            pSub.setAlignment(Element.ALIGN_CENTER);
            headerCell.addElement(pSub);

            Paragraph pMeta = new Paragraph("Comunidad: " + op.comunidad().getNombre()
                    + " | Fecha de Generación: " + LocalDate.now().format(DATE_FMT), fontSmall);
            pMeta.setAlignment(Element.ALIGN_CENTER);
            headerCell.addElement(pMeta);

            headerTable.addCell(headerCell);
            document.add(headerTable);

            // ==================== SECCIÓN 1: DATOS DE LA ACTIVIDAD ====================
            Paragraph sec1 = new Paragraph("1. DATOS DE LA ACTIVIDAD", fontSectionTitle);
            sec1.setSpacingAfter(6);
            document.add(sec1);

            PdfPTable infoTable = new PdfPTable(4);
            infoTable.setWidthPercentage(100);
            infoTable.setWidths(new float[]{25, 25, 25, 25});
            infoTable.setSpacingAfter(8);

            long aprobadas = op.todas().stream().filter(a -> a.getEstado() == EstadoActividad.APROBADA).count();
            String reqs = (Boolean.TRUE.equals(ref.getRequiereFotografia()) ? "Foto " : "")
                    + (Boolean.TRUE.equals(ref.getRequiereDocumento()) ? "Doc" : "");

            agregarCeldaInfo(infoTable, "Actividad:", textoONa(ref.getTitulo()), fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Coordinador:", ref.getCoordinador() != null
                    ? nombreCompleto(ref.getCoordinador().getUsuario()) : "No asignado", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Fecha Creación:", ref.getFechaCreacion() != null
                    ? ref.getFechaCreacion().format(DATE_FMT) : "N/A", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Fecha Límite:", ref.getFechaLimite() != null
                    ? ref.getFechaLimite().format(DATE_FMT) : "N/A", fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Requisitos:", reqs.isBlank() ? "Ninguno" : reqs.trim(), fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Apadrinados:", String.valueOf(op.apadrinados().size()), fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Asignadas:", String.valueOf(op.todas().size()), fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Aprobadas:", String.valueOf(aprobadas), fontLabel, fontValue);
            document.add(infoTable);

            if (ref.getDescripcion() != null && !ref.getDescripcion().isBlank()) {
                Paragraph desc = new Paragraph(ref.getDescripcion(), fontValue);
                desc.setSpacingAfter(15);
                document.add(desc);
            }

            // ==================== SECCIÓN 2: ESTADO POR APADRINADO ====================
            Paragraph sec2 = new Paragraph("2. ESTADO POR APADRINADO (" + op.filas().size() + ")", fontSectionTitle);
            sec2.setSpacingAfter(6);
            document.add(sec2);

            PdfPTable estTable = new PdfPTable(5);
            estTable.setWidthPercentage(100);
            estTable.setWidths(new float[]{26, 16, 26, 10, 22});
            estTable.setSpacingAfter(15);

            agregarCeldaCabecera(estTable, "Apadrinado", fontTableHead);
            agregarCeldaCabecera(estTable, "Estado", fontTableHead);
            agregarCeldaCabecera(estTable, "Última Acción", fontTableHead);
            agregarCeldaCabecera(estTable, "Evidencias", fontTableHead);
            agregarCeldaCabecera(estTable, "Observaciones", fontTableHead);

            if (!op.filas().isEmpty()) {
                boolean alt = false;
                for (FilaApadrinado fila : op.filas()) {
                    Color bg = alt ? COLOR_BG_ALT : Color.WHITE;
                    alt = !alt;
                    Actividad act = fila.actividad();

                    agregarCeldaCuerpo(estTable, nombreCompleto(fila.apadrinado().getUsuario()), fontTableBody, bg);
                    agregarCeldaCuerpo(estTable, act != null && act.getEstado() != null
                            ? act.getEstado().name() : "SIN ASIGNAR", fontTableBody, bg);

                    String ultima = "-";
                    if (fila.ultimaAccion() != null) {
                        HistorialActividad h = fila.ultimaAccion();
                        ultima = (h.getFechaHora() != null ? h.getFechaHora().format(DATETIME_FMT) + " - " : "")
                                + textoONa(h.getAccion());
                    }
                    agregarCeldaCuerpo(estTable, ultima, fontTableBody, bg);
                    agregarCeldaCuerpo(estTable, String.valueOf(fila.documentos().size()), fontTableBody, bg);
                    agregarCeldaCuerpo(estTable, act != null && act.getObservaciones() != null
                            ? act.getObservaciones() : "-", fontTableBody, bg);
                }
            } else {
                PdfPCell vacio = new PdfPCell(new Phrase(soloAprobadas
                        ? "Ningún apadrinado tiene esta actividad aprobada."
                        : "No hay apadrinados en esta comunidad.", fontTableBody));
                vacio.setColspan(5);
                vacio.setPadding(8);
                vacio.setHorizontalAlignment(Element.ALIGN_CENTER);
                estTable.addCell(vacio);
            }
            document.add(estTable);

            // ==================== SECCIÓN 3: EVIDENCIAS ENTREGADAS ====================
            List<FilaApadrinado> conEvidencias = op.filas().stream()
                    .filter(f -> !f.documentos().isEmpty())
                    .collect(Collectors.toList());
            int totalDocs = conEvidencias.stream().mapToInt(f -> f.documentos().size()).sum();

            Paragraph sec3 = new Paragraph("3. EVIDENCIAS ENTREGADAS (" + totalDocs + ")", fontSectionTitle);
            sec3.setSpacingAfter(6);
            document.add(sec3);

            PdfPTable docTable = new PdfPTable(4);
            docTable.setWidthPercentage(100);
            docTable.setWidths(new float[]{26, 18, 36, 20});
            docTable.setSpacingAfter(20);

            agregarCeldaCabecera(docTable, "Apadrinado", fontTableHead);
            agregarCeldaCabecera(docTable, "Tipo", fontTableHead);
            agregarCeldaCabecera(docTable, "Nombre Archivo", fontTableHead);
            agregarCeldaCabecera(docTable, "Fecha Subida", fontTableHead);

            if (totalDocs > 0) {
                boolean alt = false;
                for (FilaApadrinado fila : conEvidencias) {
                    for (Documento doc : fila.documentos()) {
                        Color bg = alt ? COLOR_BG_ALT : Color.WHITE;
                        alt = !alt;
                        agregarCeldaCuerpo(docTable, nombreCompleto(fila.apadrinado().getUsuario()), fontTableBody, bg);
                        agregarCeldaCuerpo(docTable, doc.getTipoDocumento() != null
                                ? doc.getTipoDocumento().name() : "OTRO", fontTableBody, bg);
                        agregarCeldaCuerpo(docTable, textoONa(doc.getNombreOriginal()), fontTableBody, bg);
                        agregarCeldaCuerpo(docTable, doc.getFechaSubida() != null
                                ? doc.getFechaSubida().format(DATETIME_FMT) : "-", fontTableBody, bg);
                    }
                }
            } else {
                PdfPCell vacio = new PdfPCell(new Phrase("No hay evidencias entregadas para esta actividad.", fontTableBody));
                vacio.setColspan(4);
                vacio.setPadding(8);
                vacio.setHorizontalAlignment(Element.ALIGN_CENTER);
                docTable.addCell(vacio);
            }
            document.add(docTable);

            Paragraph pFooter = new Paragraph("Este documento es una copia oficial generada por el Sistema de Gestión Documental de la Fundación UNBOUND Huehuetenango.", fontSmall);
            pFooter.setAlignment(Element.ALIGN_CENTER);
            pFooter.setSpacingBefore(10);
            document.add(pFooter);

            document.close();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new RuntimeException("Error al generar el expediente PDF de la actividad: " + ex.getMessage(), ex);
        }
    }

    /**
     * ZIP del expediente de actividad: incluye el PDF consolidado y una
     * carpeta por apadrinado con las evidencias que entregó.
     */
    @Transactional(readOnly = true)
    public byte[] generarZipActividad(Long actividadId, Long comunidadId, boolean soloAprobadas) {
        OperacionActividad op = cargarOperacion(actividadId, comunidadId, soloAprobadas);

        try (ByteArrayOutputStream out = new ByteArrayOutputStream();
             ZipOutputStream zipOut = new ZipOutputStream(out)) {

            zipOut.putNextEntry(new ZipEntry("Expediente_Actividad_" + actividadId + ".pdf"));
            zipOut.write(generarPdfActividad(actividadId, comunidadId, soloAprobadas));
            zipOut.closeEntry();

            for (FilaApadrinado fila : op.filas()) {
                if (fila.documentos().isEmpty()) continue;
                String carpeta = nombreSeguro(nombreCompleto(fila.apadrinado().getUsuario()))
                        + "_" + fila.apadrinado().getId() + "/";
                for (Documento doc : fila.documentos()) {
                    agregarDocumentoAlZip(zipOut, carpeta + doc.getId() + "_"
                            + (doc.getNombreOriginal() != null ? doc.getNombreOriginal() : "documento"), doc);
                }
            }

            zipOut.finish();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new RuntimeException("Error al generar el ZIP de la actividad: " + ex.getMessage(), ex);
        }
    }

    private record FilaApadrinado(Apadrinado apadrinado, Actividad actividad,
                                  HistorialActividad ultimaAccion, List<Documento> documentos) {}

    private record OperacionActividad(Actividad referencia, Comunidad comunidad, List<Actividad> todas,
                                      List<Apadrinado> apadrinados, List<FilaApadrinado> filas) {}

    private OperacionActividad cargarOperacion(Long actividadId, Long comunidadId, boolean soloAprobadas) {
        Actividad ref = actividadRepository.findById(actividadId)
                .orElseThrow(() -> new RuntimeException("Actividad no encontrada con ID: " + actividadId));
        Long idComunidad = resolverComunidadActividad(actividadId, comunidadId);
        Comunidad comunidad = comunidadRepository.findById(idComunidad)
                .orElseThrow(() -> new RuntimeException("Comunidad no encontrada con ID: " + idComunidad));

        String clave = claveOperacion(ref);
        List<Actividad> todas = actividadRepository.findByApadrinadoComunidadId(idComunidad).stream()
                .filter(a -> claveOperacion(a).equals(clave))
                .collect(Collectors.toList());
        Map<Long, Actividad> porApadrinado = new LinkedHashMap<>();
        for (Actividad a : todas) {
            porApadrinado.putIfAbsent(a.getApadrinado().getId(), a);
        }

        List<Apadrinado> apadrinados = apadrinadoRepository.findByComunidadId(idComunidad);
        List<FilaApadrinado> filas = apadrinados.stream()
                .sorted(Comparator.comparing(a -> nombreCompleto(a.getUsuario()), String.CASE_INSENSITIVE_ORDER))
                .map(apad -> {
                    Actividad act = porApadrinado.get(apad.getId());
                    if (act == null) {
                        return new FilaApadrinado(apad, null, null, List.of());
                    }
                    HistorialActividad ultima = historialActividadRepository
                            .findByActividadIdOrderByFechaHoraDesc(act.getId())
                            .stream().findFirst().orElse(null);
                    return new FilaApadrinado(apad, act, ultima, documentoRepository.findByActividadId(act.getId()));
                })
                .filter(f -> !soloAprobadas
                        || (f.actividad() != null && f.actividad().getEstado() == EstadoActividad.APROBADA))
                .collect(Collectors.toList());

        return new OperacionActividad(ref, comunidad, todas, apadrinados, filas);
    }

    /** Clave de una operación de creación masiva: título + fecha de creación. */
    private String claveOperacion(Actividad a) {
        return (a.getTitulo() != null ? a.getTitulo().trim().toLowerCase() : "")
                + "|" + a.getFechaCreacion();
    }

    // ==================== UTILIDADES ====================

    /** Valida que el intervalo [desde, hasta] sea coherente. */
    public static void validarIntervalo(LocalDate desde, LocalDate hasta) {
        if (desde != null && hasta != null && desde.isAfter(hasta)) {
            throw new IllegalArgumentException("La fecha 'desde' no puede ser posterior a la fecha 'hasta'.");
        }
    }

    /** {@code true} si la fecha está en [desde, hasta]; un extremo nulo no limita. */
    private static boolean enIntervaloFecha(LocalDate fecha, LocalDate desde, LocalDate hasta) {
        if (fecha == null) return false;
        if (desde != null && fecha.isBefore(desde)) return false;
        return hasta == null || !fecha.isAfter(hasta);
    }

    /** {@code true} si la fecha/hora está en [desde, hasta]; un extremo nulo no limita. */
    private static boolean enIntervaloFechaHora(LocalDateTime fecha, LocalDateTime desde, LocalDateTime hasta) {
        if (fecha == null) return false;
        if (desde != null && fecha.isBefore(desde)) return false;
        return hasta == null || !fecha.isAfter(hasta);
    }

    private static String nombreCompleto(Usuario usuario) {
        if (usuario == null) return "N/A";
        String nombre = (usuario.getNombre() != null ? usuario.getNombre() : "")
                + (usuario.getApellido() != null ? " " + usuario.getApellido() : "");
        return nombre.isBlank() ? "N/A" : nombre.trim();
    }

    private static String textoONa(String s) {
        return s != null && !s.isBlank() ? s : "N/A";
    }

    /** Nombre apto para carpeta dentro del ZIP. */
    private static String nombreSeguro(String s) {
        return s.replaceAll("[^\\p{L}\\p{N}._-]+", "_");
    }

    private void agregarDocumentoAlZip(ZipOutputStream zipOut, String rutaZip, Documento doc) {
        try {
            Resource resource = fileStorageService.loadFileAsResource(doc.getNombreAlmacenado());
            if (resource.exists() && resource.isReadable()) {
                zipOut.putNextEntry(new ZipEntry(rutaZip));
                try (InputStream in = resource.getInputStream()) {
                    in.transferTo(zipOut);
                }
                zipOut.closeEntry();
                return;
            }
        } catch (Exception ignored) {
            // Se registra un marcador con los metadatos del documento
        }
        agregarPlaceholder(zipOut, rutaZip + ".txt", doc);
    }

    private void agregarPlaceholder(ZipOutputStream zipOut, String rutaZip, Documento doc) {
        try {
            zipOut.putNextEntry(new ZipEntry(rutaZip));
            String contenido = "Metadatos de Documento:\n"
                    + "ID: " + doc.getId() + "\n"
                    + "Nombre Original: " + doc.getNombreOriginal() + "\n"
                    + "Tipo: " + doc.getTipoDocumento() + "\n"
                    + "Fecha Subida: " + doc.getFechaSubida() + "\n"
                    + "Descripción: " + doc.getDescripcion() + "\n"
                    + "Nota: El archivo físico está registrado en la base de datos.";
            zipOut.write(contenido.getBytes(StandardCharsets.UTF_8));
            zipOut.closeEntry();
        } catch (Exception ignored) {}
    }

    private void agregarCeldaInfo(PdfPTable table, String label, String val, Font fontLabel, Font fontVal) {
        PdfPCell cLabel = new PdfPCell(new Phrase(label, fontLabel));
        cLabel.setBackgroundColor(COLOR_BG_HEADER);
        cLabel.setBorderColor(COLOR_BORDER);
        cLabel.setPadding(5);

        PdfPCell cVal = new PdfPCell(new Phrase(val, fontVal));
        cVal.setBackgroundColor(Color.WHITE);
        cVal.setBorderColor(COLOR_BORDER);
        cVal.setPadding(5);

        table.addCell(cLabel);
        table.addCell(cVal);
    }

    private void agregarCeldaCabecera(PdfPTable table, String text, Font font) {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setBackgroundColor(COLOR_PRIMARY);
        cell.setBorderColor(COLOR_PRIMARY);
        cell.setPadding(5);
        cell.setHorizontalAlignment(Element.ALIGN_CENTER);
        table.addCell(cell);
    }

    private void agregarCeldaCuerpo(PdfPTable table, String text, Font font, Color bg) {
        PdfPCell cell = new PdfPCell(new Phrase(text, font));
        cell.setBackgroundColor(bg);
        cell.setBorderColor(COLOR_BORDER);
        cell.setPadding(4);
        table.addCell(cell);
    }
}
