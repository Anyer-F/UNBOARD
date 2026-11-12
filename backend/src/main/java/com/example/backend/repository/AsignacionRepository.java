package com.example.backend.repository;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import com.example.backend.entity.Asignacion;
import com.example.backend.entity.EstadoActividad;

@Repository
public interface AsignacionRepository extends JpaRepository<Asignacion, Long> {

    List<Asignacion> findByActividadIdOrderByApadrinadoUsuarioNombreAsc(Long actividadId);

    Optional<Asignacion> findByActividadIdAndApadrinadoId(Long actividadId, Long apadrinadoId);

    boolean existsByActividadIdAndApadrinadoId(Long actividadId, Long apadrinadoId);

    List<Asignacion> findByActividadIdIn(Collection<Long> actividadIds);

    /** Asignaciones visibles del apadrinado (actividades no eliminadas). */
    @Query("SELECT s FROM Asignacion s WHERE s.apadrinado.id = :apadrinadoId "
            + "AND s.actividad.eliminada = false ORDER BY s.fechaAsignacion DESC")
    List<Asignacion> findVisiblesPorApadrinado(@Param("apadrinadoId") Long apadrinadoId);

    /** Asignaciones del apadrinado dentro de un intervalo de fechas de asignación. */
    @Query("SELECT s FROM Asignacion s WHERE s.apadrinado.id = :apadrinadoId "
            + "AND s.fechaAsignacion >= :desde AND s.fechaAsignacion < :hasta "
            + "ORDER BY s.fechaAsignacion ASC")
    List<Asignacion> findPorApadrinadoEnIntervalo(
            @Param("apadrinadoId") Long apadrinadoId,
            @Param("desde") LocalDateTime desde,
            @Param("hasta") LocalDateTime hasta);

    List<Asignacion> findByApadrinadoIdOrderByFechaAsignacionAsc(Long apadrinadoId);

    /** Tareas cuya fecha límite ya pasó sin que la entrega se enviara. */
    @Query("SELECT s FROM Asignacion s WHERE s.actividad.tipo = com.example.backend.entity.TipoActividad.TAREA "
            + "AND s.actividad.eliminada = false AND s.actividad.fechaLimite < :hoy "
            + "AND s.estado IN :estados")
    List<Asignacion> findTareasVencidas(
            @Param("hoy") LocalDate hoy,
            @Param("estados") Collection<EstadoActividad> estados);

    /** Tareas con fecha límite próxima a las que aún no se les envió recordatorio. */
    @Query("SELECT s FROM Asignacion s WHERE s.actividad.tipo = com.example.backend.entity.TipoActividad.TAREA "
            + "AND s.actividad.eliminada = false AND s.recordatorioEnviado = false "
            + "AND s.actividad.fechaLimite >= :desde AND s.actividad.fechaLimite <= :hasta "
            + "AND s.estado IN :estados")
    List<Asignacion> findParaRecordatorio(
            @Param("desde") LocalDate desde,
            @Param("hasta") LocalDate hasta,
            @Param("estados") Collection<EstadoActividad> estados);

    /** Las entregas y sugerencias se eliminan en cascada en la base de datos. */
    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM Asignacion s WHERE s.actividad.id = :actividadId")
    int eliminarPorActividad(@Param("actividadId") Long actividadId);

    @Modifying(flushAutomatically = true, clearAutomatically = true)
    @Query("DELETE FROM Asignacion s WHERE s.id = :asignacionId")
    int eliminarPorId(@Param("asignacionId") Long asignacionId);
}
