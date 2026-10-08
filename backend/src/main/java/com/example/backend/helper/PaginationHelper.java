package com.example.backend.helper;

import java.util.List;
import java.util.function.Function;
import java.util.stream.Collectors;

import org.springframework.data.domain.Page;

import com.example.backend.dto.PagedResponseDTO;

public class PaginationHelper {

    public static <T, R> PagedResponseDTO<R> convertToPagedResponse(Page<T> page, Function<T, R> mapper) {
        List<R> contenido = page.getContent().stream()
                .map(mapper)
                .collect(Collectors.toList());

        return PagedResponseDTO.<R>builder()
                .contenido(contenido)
                .paginaActual(page.getNumber())
                .tamanoPagina(page.getSize())
                .totalElementos(page.getTotalElements())
                .totalPaginas(page.getTotalPages())
                .ultima(page.isLast())
                .primera(page.isFirst())
                .vacia(page.isEmpty())
                .build();
    }

    public static <T> PagedResponseDTO<T> convertToPagedResponse(Page<T> page) {
        return PagedResponseDTO.<T>builder()
                .contenido(page.getContent())
                .paginaActual(page.getNumber())
                .tamanoPagina(page.getSize())
                .totalElementos(page.getTotalElements())
                .totalPaginas(page.getTotalPages())
                .ultima(page.isLast())
                .primera(page.isFirst())
                .vacia(page.isEmpty())
                .build();
    }
}
