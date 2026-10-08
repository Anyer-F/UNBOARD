package com.example.backend.service;

import java.awt.Color;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;

import org.springframework.core.io.Resource;
import org.springframework.stereotype.Service;

import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.ApadrinadoResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.ExpedienteResponseDTO;
import com.example.backend.dto.HistorialActividadResponseDTO;
import com.example.backend.entity.Documento;
import com.example.backend.entity.Expediente;
import com.example.backend.repository.DocumentoRepository;
import com.example.backend.repository.ExpedienteRepository;
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
        Expediente expediente = expedienteRepository.findById(expedienteId)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + expedienteId));

        ExpedienteResponseDTO dto = expedienteService.convertirAResponseDTO(expediente, true);
        ApadrinadoResponseDTO apadrinado = dto.getApadrinado();
        List<ActividadResponseDTO> actividades = dto.getActividades();
        List<DocumentoResponseDTO> documentos = dto.getDocumentos();

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

            Paragraph pMeta = new Paragraph("Expediente #" + dto.getId() + " | Fecha de Generación: " + java.time.LocalDate.now().format(DATE_FMT), fontSmall);
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
            agregarCeldaInfo(infoTable, "Total Actividades:", String.valueOf(dto.getTotalActividades()), fontLabel, fontValue);
            agregarCeldaInfo(infoTable, "Total Documentos:", String.valueOf(dto.getTotalDocumentos()), fontLabel, fontValue);
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
        Expediente expediente = expedienteRepository.findById(expedienteId)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + expedienteId));

        ExpedienteResponseDTO dto = expedienteService.convertirAResponseDTO(expediente, true);
        List<Documento> documentos = documentoRepository.findByExpedienteId(expedienteId);

        try (ByteArrayOutputStream out = new ByteArrayOutputStream();
             ZipOutputStream zipOut = new ZipOutputStream(out)) {

            // 1. Incluir el PDF consolidado del expediente dentro del ZIP
            byte[] pdfBytes = generarPdfConsolidado(expedienteId);
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
                String rutaZip = subCarpeta + nombreArchivo;

                try {
                    Resource resource = fileStorageService.loadFileAsResource(doc.getNombreAlmacenado());
                    if (resource.exists() && resource.isReadable()) {
                        zipOut.putNextEntry(new ZipEntry(rutaZip));
                        try (InputStream in = resource.getInputStream()) {
                            in.transferTo(zipOut);
                        }
                        zipOut.closeEntry();
                    } else {
                        agregarPlaceholder(zipOut, rutaZip + ".txt", doc);
                    }
                } catch (Exception ex) {
                    agregarPlaceholder(zipOut, rutaZip + ".txt", doc);
                }
            }

            zipOut.finish();
            return out.toByteArray();
        } catch (Exception ex) {
            throw new RuntimeException("Error al generar el archivo ZIP del expediente: " + ex.getMessage(), ex);
        }
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
