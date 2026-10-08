package com.example.backend.service;

import java.time.LocalDate;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.ActividadResponseDTO;
import com.example.backend.dto.ApadrinadoResponseDTO;
import com.example.backend.dto.DocumentoResponseDTO;
import com.example.backend.dto.ExpedienteResponseDTO;
import com.example.backend.entity.Apadrinado;
import com.example.backend.entity.Expediente;
import com.example.backend.repository.ApadrinadoRepository;
import com.example.backend.repository.ExpedienteRepository;

import lombok.RequiredArgsConstructor;

@Service
@RequiredArgsConstructor
public class ExpedienteService {

    private final ExpedienteRepository expedienteRepository;
    private final ApadrinadoRepository apadrinadoRepository;
    private final DocumentoService documentoService;
    private final ActividadService actividadService;
    private final ApadrinadoService apadrinadoService;

    @Transactional(readOnly = true)
    public List<ExpedienteResponseDTO> listarTodos() {
        return expedienteRepository.findAll().stream()
                .map(exp -> convertirAResponseDTO(exp, false))
                .collect(Collectors.toList());
    }

    @Transactional(readOnly = true)
    public ExpedienteResponseDTO obtenerPorId(Long id) {
        Expediente expediente = expedienteRepository.findById(id)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado con ID: " + id));
        return convertirAResponseDTO(expediente, true);
    }

    @Transactional(readOnly = true)
    public ExpedienteResponseDTO obtenerPorApadrinadoId(Long apadrinadoId) {
        Expediente expediente = expedienteRepository.findByApadrinadoId(apadrinadoId)
                .orElseThrow(() -> new RuntimeException("Expediente no encontrado para el apadrinado ID: " + apadrinadoId));
        return convertirAResponseDTO(expediente, true);
    }

    @Transactional(readOnly = true)
    public List<ExpedienteResponseDTO> listarPorCoordinador(Long coordinadorId) {
        return expedienteRepository.findByApadrinadoCoordinadorId(coordinadorId).stream()
                .map(exp -> convertirAResponseDTO(exp, false))
                .collect(Collectors.toList());
    }

    @Transactional
    public ExpedienteResponseDTO crearParaApadrinado(Long apadrinadoId) {
        if (expedienteRepository.existsByApadrinadoId(apadrinadoId)) {
            throw new RuntimeException("Ya existe un expediente para el apadrinado ID: " + apadrinadoId);
        }

        Apadrinado apadrinado = apadrinadoRepository.findById(apadrinadoId)
                .orElseThrow(() -> new RuntimeException("Apadrinado no encontrado con ID: " + apadrinadoId));

        Expediente expediente = Expediente.builder()
                .apadrinado(apadrinado)
                .fechaCreacion(LocalDate.now())
                .build();

        Expediente guardado = expedienteRepository.save(expediente);
        return convertirAResponseDTO(guardado, true);
    }

    public ExpedienteResponseDTO convertirAResponseDTO(Expediente expediente, boolean incluirDetalles) {
        ApadrinadoResponseDTO apadrinadoDTO = null;
        List<DocumentoResponseDTO> documentos = null;
        List<ActividadResponseDTO> actividades = null;
        Integer totalDocs = 0;
        Integer totalActs = 0;

        if (expediente.getApadrinado() != null) {
            apadrinadoDTO = apadrinadoService.convertirAResponseDTO(expediente.getApadrinado());

            if (incluirDetalles) {
                documentos = documentoService.listarPorExpediente(expediente.getId(), null);
                actividades = actividadService.listarPorApadrinado(expediente.getApadrinado().getId(), null);
                totalDocs = documentos != null ? documentos.size() : 0;
                totalActs = actividades != null ? actividades.size() : 0;
            }
        }

        return ExpedienteResponseDTO.builder()
                .id(expediente.getId())
                .codigo(expediente.getCodigo())
                .estado(expediente.getEstado())
                .apadrinado(apadrinadoDTO)
                .fechaCreacion(expediente.getFechaCreacion())
                .documentos(documentos)
                .actividades(actividades)
                .totalDocumentos(totalDocs)
                .totalActividades(totalActs)
                .build();
    }
}
