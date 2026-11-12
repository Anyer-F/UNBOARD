package com.example.backend.service;

import java.util.Comparator;
import java.util.List;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.example.backend.dto.CartaResponseDTO;
import com.example.backend.repository.CartaRepository;

import lombok.RequiredArgsConstructor;

/**
 * Consulta de cartas. Las cartas se escriben como parte de la entrega de
 * una tarea (ver {@link EntregaService}) y quedan en el expediente.
 */
@Service
@RequiredArgsConstructor
public class CartaService {

    private final CartaRepository cartaRepository;
    private final SeguridadService seguridadService;
    private final ConvertidorDTO convertidor;

    @Transactional(readOnly = true)
    public CartaResponseDTO obtenerPorId(Long id) {
        return convertidor.carta(seguridadService.verificarCartaAccesible(id));
    }

    /** Cartas del apadrinado (coordinador, para su expediente). */
    @Transactional(readOnly = true)
    public List<CartaResponseDTO> listarPorApadrinado(Long apadrinadoId) {
        seguridadService.verificarApadrinadoDeMiComunidad(apadrinadoId);
        return cartaRepository.findByApadrinadoId(apadrinadoId).stream()
                .sorted(Comparator.comparing(c -> c.getFechaCreacion(), Comparator.nullsLast(Comparator.reverseOrder())))
                .map(convertidor::carta)
                .collect(Collectors.toList());
    }
}
