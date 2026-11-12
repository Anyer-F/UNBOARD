// Fase G: prueba de extremo a extremo del flujo de la "Descripción del proyecto v2".
//
// Requiere la pila levantada (docker compose up -d) y el coordinador de prueba
// carlos.mendez@unbound.org / password123. Crea su propia comunidad, código,
// apadrinados y actividades, por lo que se puede ejecutar varias veces.
//
//   node faseG_tests.mjs            (API en http://localhost:8081/api)
//   API=https://servidor/api node faseG_tests.mjs

const B = process.env.API || 'http://localhost:8081/api';
const COORDINADOR = process.env.COORDINADOR || 'carlos.mendez@unbound.org';
const CLAVE_COORDINADOR = process.env.CLAVE_COORDINADOR || 'password123';

let ok = 0;
let fail = 0;
const check = (cond, msg, extra) => {
  if (cond) {
    ok++;
    console.log('  ✓ ' + msg);
  } else {
    fail++;
    console.log('  ✗ ' + msg + (extra !== undefined ? ' -> ' + JSON.stringify(extra).slice(0, 300) : ''));
  }
};

async function req(token, method, path, body, form) {
  const headers = {};
  if (token) headers.Authorization = 'Bearer ' + token;
  let payload;
  if (form) {
    payload = form;
  } else if (body !== undefined) {
    headers['Content-Type'] = 'application/json';
    payload = JSON.stringify(body);
  }
  const r = await fetch(B + path, { method, headers, body: payload });
  const ct = r.headers.get('content-type') || '';
  const data = ct.includes('json') ? await r.json() : Buffer.from(await r.arrayBuffer());
  return { status: r.status, data };
}

const login = async (correo, password) =>
  (await req(null, 'POST', '/auth/login', { correo, password })).data;

const archivo = (nombre, contenido, tipo) => {
  const fd = new FormData();
  fd.append('file', new Blob([contenido], { type: tipo }), nombre);
  return fd;
};

// PNG de 1x1
const PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==', 'base64');
const hoy = new Date();
const fecha = (dias) => new Date(hoy.getTime() + dias * 86400000).toISOString().slice(0, 10);
const sello = Date.now();

const TC = (await login(COORDINADOR, CLAVE_COORDINADOR)).token;
if (!TC) {
  console.error('No se pudo iniciar sesión como coordinador (' + COORDINADOR + ').');
  process.exit(2);
}

/** Registra un apadrinado y lo incorpora a la comunidad con el código. */
async function nuevoApadrinado(nombre, apellido, codigo) {
  const correo = `${nombre.toLowerCase()}.${sello}@prueba.unboard`;
  const reg = await req(null, 'POST', '/auth/register',
    { nombre, apellido, correo, password: 'clave123', telefono: '5555-0101' });
  const sol = await req(reg.data.token, 'POST', '/solicitudes-incorporacion', { codigo });
  return { correo, registro: reg, solicitud: sol };
}

console.log('\n== Comunidad, código y módulos');
let r = await req(TC, 'POST', '/comunidades',
  { nombre: 'Aldea Prueba ' + sello, municipio: 'Chiantla', departamento: 'Huehuetenango' });
check(r.status === 201 && r.data.modoIncorporacion === 'SOLICITUD', 'crear comunidad (incorporación con solicitud)', r.data);
const com = r.data.id;
r = await req(TC, 'GET', '/comunidades');
check(r.data.some((c) => c.id === com), 'la comunidad nueva queda bajo su responsabilidad');
r = await req(TC, 'GET', `/comunidades/${com}/modulos`);
check(r.data.length === 1 && r.data[0].nombre === 'Módulo 1', 'se crea el Módulo 1 automáticamente', r.data);
const mod1 = r.data[0].id;
r = await req(TC, 'POST', `/codigos-acceso/comunidad/${com}`, { maxUsos: 10, descripcion: 'Prueba' });
check(r.status === 201 || r.status === 200, 'generar código de acceso', r.data);
const codigo = r.data.codigo;

console.log('\n== Registro e incorporación');
const maria = await nuevoApadrinado('Maria', 'Lopez', codigo.toLowerCase());
check(maria.registro.status === 201 && maria.registro.data.rol === 'Apadrinado', 'registro público crea un apadrinado', maria.registro.data);
check(maria.solicitud.status === 201 && maria.solicitud.data.estado === 'PENDIENTE', 'solicitud con el código (sin indicar comunidad)', maria.solicitud.data);
r = await req(maria.registro.data.token, 'GET', '/comunidades/mia');
check(r.status === 403, 'antes de ser aceptada no tiene comunidad');
r = await req(maria.registro.data.token, 'GET', '/solicitudes-incorporacion/mias');
check(r.data[0].estado === 'PENDIENTE', 'consulta el estado de su solicitud');
r = await req(TC, 'GET', `/solicitudes-incorporacion/${maria.solicitud.data.id}`);
check(r.data.usuarioTelefono === '5555-0101' && r.data.usuarioApellido === 'Lopez', 'el coordinador consulta el perfil del solicitante');
r = await req(TC, 'PATCH', `/solicitudes-incorporacion/${maria.solicitud.data.id}/aprobar`);
check(r.data.estado === 'APROBADA', 'aceptar solicitud');
const jose = await nuevoApadrinado('Jose', 'Ramirez', codigo);
await req(TC, 'PATCH', `/solicitudes-incorporacion/${jose.solicitud.data.id}/aprobar`);
const ana = await nuevoApadrinado('Ana', 'Garcia', codigo);
r = await req(TC, 'PATCH', `/solicitudes-incorporacion/${ana.solicitud.data.id}/rechazar?observaciones=Datos%20incompletos`);
check(r.data.estado === 'RECHAZADA', 'rechazar solicitud');

const SM = await login(maria.correo, 'clave123');
const SJ = await login(jose.correo, 'clave123');
const TM = SM.token;
const TJ = SJ.token;
check(SM.apadrinadoId && SJ.apadrinadoId, 'los aceptados ya son apadrinados de la comunidad');
r = await req(TM, 'POST', '/solicitudes-incorporacion', { codigo });
check(r.status === 403, 'no puede cambiarse libremente de comunidad');

await req(TC, 'PUT', `/comunidades/${com}`, { modoIncorporacion: 'DIRECTO' });
const pedro = await nuevoApadrinado('Pedro', 'Gomez', codigo);
check(pedro.solicitud.data.estado === 'APROBADA', 'en modo DIRECTO el código incorpora de inmediato', pedro.solicitud.data);
const TP = (await login(pedro.correo, 'clave123')).token;

r = await req(TC, 'POST', `/comunidades/${com}/modulos`, { nombre: 'Módulo 2: Educación', descripcion: 'Tareas escolares' });
check(r.status === 201 && r.data.orden === 2, 'crear Módulo 2', r.data);
const mod2 = r.data.id;
r = await req(TC, 'PUT', `/modulos/${mod1}`, { nombre: 'Módulo 1: Bienvenida' });
check(r.data.nombre === 'Módulo 1: Bienvenida', 'renombrar el Módulo 1');
r = await req(TC, 'PUT', `/comunidades/${com}/modulos/orden`, { ids: [mod2, mod1] });
check(r.data[0].id === mod2, 'reordenar módulos', r.data);
await req(TC, 'PUT', `/comunidades/${com}/modulos/orden`, { ids: [mod1, mod2] });

console.log('\n== Actividades (coordinador)');
r = await req(TC, 'POST', '/actividades',
  { tipo: 'TAREA', titulo: 'Sin módulo', comunidadId: com, fechaLimite: fecha(5), asignarAComunidad: true });
check(r.status === 400 && /módulo/i.test(r.data.message), 'con varios módulos hay que elegir el módulo', r.data);
r = await req(TC, 'POST', '/actividades',
  { tipo: 'TAREA', titulo: 'Sin fecha', comunidadId: com, moduloId: mod2, asignarAComunidad: true });
check(r.status === 400 && /fecha límite/.test(r.data.message), 'una tarea sin fecha límite es rechazada');
r = await req(TC, 'POST', '/actividades', {
  tipo: 'TAREA', titulo: 'Foto con mi familia', descripcion: 'Comparte un momento',
  instrucciones: 'Sube una foto y escribe una carta', comunidadId: com, moduloId: mod2,
  fechaLimite: fecha(2), requiereFotografia: true, requiereCarta: true,
  asignarAComunidad: false, apadrinadoIds: [SM.apadrinadoId, SJ.apadrinadoId],
});
check(r.status === 201 && r.data.resumen.asignados === 2 && r.data.resumen.pendientes === 2,
  'crear tarea para apadrinados seleccionados', r.data);
const tarea = r.data.id;
r = await req(TC, 'POST', `/actividades/${tarea}/adjuntos`, null, archivo('instrucciones.txt', 'Guía de la tarea', 'text/plain'));
check(r.status === 201 && r.data.origen === 'COORDINADOR', 'subir contenido del coordinador a la tarea', r.data);
r = await req(TC, 'POST', '/actividades', {
  tipo: 'ANUNCIO', titulo: 'Reunión el sábado', descripcion: 'En la escuela', comunidadId: com, moduloId: mod1,
  fechaLimite: fecha(3), asignarAComunidad: true,
});
check(r.status === 201 && r.data.fechaLimite === null && r.data.resumen.publicados === 3,
  'anuncio a toda la comunidad (sin fecha límite)', r.data);
const anuncio = r.data.id;
r = await req(TC, 'POST', '/actividades',
  { tipo: 'MATERIAL_APOYO', titulo: 'Guía de salud', comunidadId: com, moduloId: mod1, asignarAComunidad: true });
check(r.status === 201, 'material de apoyo para toda la comunidad');
r = await req(TC, 'GET', `/actividades?comunidadId=${com}&tipo=TAREA`);
check(r.data.length === 1 && r.data[0].id === tarea, 'tablero filtrado por comunidad y tipo');
r = await req(TC, 'GET', `/actividades?comunidadId=${com}&moduloId=${mod1}`);
check(r.data.length === 2 && r.data.every((a) => a.moduloId === mod1), 'tablero filtrado por módulo');

console.log('\n== Control de acceso');
r = await req(TM, 'GET', '/actividades');
check(r.status === 403, 'el apadrinado no accede al tablero del coordinador');
r = await req(TM, 'GET', `/expedientes/apadrinado/${SM.apadrinadoId}`);
check(r.status === 403, 'el apadrinado no accede a su expediente');
r = await req(TM, 'POST', `/expedientes/apadrinado/${SM.apadrinadoId}/exportar-pdf`);
check(r.status === 403, 'el apadrinado no genera PDF');
r = await req(TM, 'POST', `/actividades/${tarea}/exportar-zip`);
check(r.status === 403, 'el apadrinado no genera ZIP');
r = await req(TM, 'POST', '/actividades', { tipo: 'TAREA', titulo: 'x', comunidadId: com });
check(r.status === 403, 'el apadrinado no crea actividades');

console.log('\n== Apadrinado: comunidad, tablero y anuncios');
r = await req(TM, 'GET', '/comunidades/mia');
check(r.status === 200 && r.data.coordinadorNombre && r.data.modulos.length === 2, 've su comunidad, coordinador y módulos', r.data);
const m2 = r.data.modulos.find((m) => m.modulo.id === mod2);
check(m2.enProceso.some((s) => s.actividadId === tarea), 'la tarea aparece en proceso en el Módulo 2');
const m1 = r.data.modulos.find((m) => m.modulo.id === mod1);
check(m1.anuncios.length === 1 && m1.material.length === 1, 'anuncio y material en el Módulo 1');
r = await req(TP, 'GET', '/comunidades/mia');
check(!r.data.modulos.some((m) => m.enProceso.length), 'Pedro no recibe la tarea asignada solo a otros');
r = await req(TM, 'GET', '/asignaciones/tablero');
const asigM = r.data.pendientes.find((s) => s.actividadId === tarea);
check(asigM && asigM.proximaAVencer, 'tablero de pendientes con la tarea próxima a vencer', r.data);
r = await req(TM, 'POST', `/asignaciones/${m1.anuncios[0].id}/visto`);
check(r.data.estado === 'VISTO', 'abrir el anuncio lo marca como visto');
r = await req(TJ, 'GET', `/asignaciones/${asigM.id}`);
check(r.status === 403, 'otro apadrinado no ve la asignación ajena');

console.log('\n== Entrega (versión 1)');
r = await req(TM, 'GET', `/asignaciones/${asigM.id}`);
check(r.data.editable && r.data.actividad.adjuntos.length === 1, 'detalle con el material del coordinador', r.data);
r = await req(TM, 'GET', `/documentos/${r.data.actividad.adjuntos[0].id}/descargar`);
check(r.status === 200 && r.data.toString() === 'Guía de la tarea', 'el apadrinado descarga el material');
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/archivos`, null, archivo('tarea.pdf', '%PDF-1.4 prueba', 'application/pdf'));
check(r.status === 201 && r.data.tipoDocumento === 'DOCUMENTO', 'subir documento', r.data);
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/enviar`, { texto: 'Aquí va' });
check(r.status === 400 && /fotograf/.test(r.data.message), 'no se puede enviar sin la fotografía requerida', r.data);
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/archivos`, null, archivo('familia.png', PNG, 'image/png'));
check(r.data.tipoDocumento === 'FOTOGRAFIA', 'subir fotografía');
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/archivos?tipo=EVIDENCIA`, null, archivo('evidencia.txt', 'asistencia', 'text/plain'));
check(r.data.tipoDocumento === 'EVIDENCIA', 'adjuntar evidencia');
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/cartas`, { titulo: 'Querido padrino', contenido: 'Gracias por todo.' });
check(r.status === 201, 'escribir carta');
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/enviar`, { texto: 'Mi primera entrega' });
check(r.data.estado === 'ENVIADA' && r.data.version === 1, 'enviar la entrega (versión 1)', r.data);
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/archivos`, null, archivo('x.txt', 'x', 'text/plain'));
check(r.status === 400, 'una entrega enviada no se puede modificar');

console.log('\n== Revisión y corrección');
r = await req(TC, 'GET', `/actividades/${tarea}`);
check(r.data.asignaciones.find((s) => s.id === asigM.id).estado === 'ENVIADO' && r.data.tieneEntregas,
  'el detalle de la actividad muestra la entrega enviada');
r = await req(TC, 'POST', `/asignaciones/${asigM.id}/revision/iniciar`);
check(r.data.estado === 'EN_REVISION', 'iniciar revisión');
r = await req(TC, 'POST', `/asignaciones/${asigM.id}/revision/correccion`, { texto: '' });
check(r.status === 400, 'una corrección sin sugerencias es rechazada');
r = await req(TC, 'POST', `/asignaciones/${asigM.id}/revision/correccion`, { texto: 'La foto está borrosa, sube otra.' });
check(r.data.estado === 'CORRECCION_SOLICITADA' && r.data.sugerencias.length === 1, 'solicitar corrección con sugerencias');
r = await req(TM, 'GET', '/asignaciones/tablero');
const enCorreccion = r.data.pendientes.find((s) => s.id === asigM.id);
check(enCorreccion && enCorreccion.estado === 'CORRECCION_SOLICITADA' && enCorreccion.ultimaSugerencia.includes('borrosa'),
  'el apadrinado ve la corrección y la sugerencia en su tablero');

console.log('\n== Entrega (versión 2) y aprobación');
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega`);
check(r.data.version === 2 && r.data.documentos.length === 3 && r.data.cartas.length === 1, 'la versión 2 parte de los archivos de la 1', r.data);
const fotoAnterior = r.data.documentos.find((d) => d.tipoDocumento === 'FOTOGRAFIA');
r = await req(TM, 'DELETE', `/asignaciones/${asigM.id}/entrega/archivos/${fotoAnterior.id}`);
check(r.status === 204, 'quitar la foto anterior de la versión 2');
await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/archivos`, null, archivo('familia_nitida.png', PNG, 'image/png'));
r = await req(TM, 'POST', `/asignaciones/${asigM.id}/entrega/enviar`, { texto: 'Corregido' });
check(r.data.version === 2 && r.data.estado === 'ENVIADA', 'reenviar la versión 2');
r = await req(TC, 'POST', `/asignaciones/${asigM.id}/revision/aprobar`, { texto: 'Excelente trabajo' });
check(r.data.estado === 'APROBADA', 'aprobar la entrega');
r = await req(TC, 'GET', `/asignaciones/${asigM.id}`);
check(r.data.entregas.length === 2 && r.data.entregas[1].estado === 'CORRECCION_SOLICITADA' && r.data.asignacion.estado === 'APROBADO',
  'ambas versiones quedan registradas');
r = await req(TM, 'GET', '/comunidades/mia');
check(r.data.modulos.find((m) => m.modulo.id === mod2).realizadas.some((s) => s.actividadId === tarea), 'la tarea pasa a realizadas');

console.log('\n== Edición, módulos y notificaciones');
r = await req(TC, 'PUT', `/actividades/${tarea}`, {
  titulo: 'Foto con mi familia (actualizada)', fechaLimite: fecha(4),
  asignarAComunidad: false, apadrinadoIds: [SM.apadrinadoId, SJ.apadrinadoId, pedro.solicitud.data && (await login(pedro.correo, 'clave123')).apadrinadoId],
});
check(r.status === 200 && r.data.resumen.asignados === 3, 'editar nombre y fecha, y agregar un apadrinado', r.data);
r = await req(TC, 'PUT', `/actividades/${tarea}`, { asignarAComunidad: false, apadrinadoIds: [SJ.apadrinadoId] });
check(r.status === 400 && /ya realizó una entrega/.test(r.data.message), 'no se quita a quien ya entregó');
r = await req(TC, 'PATCH', `/actividades/${tarea}/modulo`, { moduloId: mod1 });
check(r.data.actividad.moduloId === mod1, 'mover la actividad a otro módulo');
await req(TC, 'PATCH', `/actividades/${tarea}/modulo`, { moduloId: mod2 });
const uM = (await req(TM, 'GET', '/usuarios/me')).data.id;
r = await req(TM, 'GET', `/notificaciones/usuario/${uM}`);
const tipos = new Set(r.data.map((n) => n.tipo));
for (const t of ['SOLICITUD_ACEPTADA', 'NUEVA_ACTIVIDAD', 'NUEVO_ANUNCIO', 'NUEVO_MATERIAL', 'ACTIVIDAD_EN_REVISION',
  'CORRECCION_SOLICITADA', 'ACTIVIDAD_APROBADA', 'ACTIVIDAD_MODIFICADA', 'DOCUMENTO_SUBIDO']) {
  check(tipos.has(t), 'notificación ' + t);
}
r = await req(ana.registro.data.token, 'GET', `/notificaciones/usuario/${ana.registro.data.usuarioId}`);
check(r.data.some((n) => n.tipo === 'SOLICITUD_RECHAZADA'), 'notificación SOLICITUD_RECHAZADA');

console.log('\n== Exportaciones');
r = await req(TC, 'POST', `/actividades/${tarea}/exportar-pdf`);
check(r.status === 201 && r.data.tipo === 'PDF_ACTIVIDAD', 'PDF de la actividad', r.data);
let d = await req(TC, 'GET', `/exportaciones/${r.data.id}/descargar`);
check(d.status === 200 && d.data.slice(0, 4).toString() === '%PDF', 'descargar el PDF de la actividad');
r = await req(TC, 'POST', `/actividades/${tarea}/exportar-zip`);
d = await req(TC, 'GET', `/exportaciones/${r.data.id}/descargar`);
let zip = d.data.toString('latin1');
check(zip.includes('Foto_con_mi_familia_actualizada/Maria_Lopez/') && zip.includes('familia_nitida.png') && !zip.includes('/familia.png'),
  'ZIP de la actividad: carpeta por apadrinado, solo la versión aprobada');
r = await req(TC, 'POST', `/expedientes/apadrinado/${SM.apadrinadoId}/exportar-pdf?desde=${fecha(-1)}&hasta=${fecha(1)}`);
d = await req(TC, 'GET', `/exportaciones/${r.data.id}/descargar`);
check(d.data.slice(0, 4).toString() === '%PDF', 'PDF del apadrinado por intervalo');
r = await req(TC, 'POST', `/expedientes/apadrinado/${SM.apadrinadoId}/exportar-zip?desde=${fecha(-1)}&hasta=${fecha(1)}`);
d = await req(TC, 'GET', `/exportaciones/${r.data.id}/descargar`);
zip = d.data.toString('latin1');
check(zip.includes('Maria_Lopez/Foto_con_mi_familia_actualizada/'), 'ZIP del apadrinado: carpeta por actividad');
r = await req(TC, 'POST', `/expedientes/apadrinado/${SJ.apadrinadoId}/exportar-zip`);
check(r.status === 400, 'ZIP sin entregas aprobadas es rechazado');
r = await req(TC, 'POST', `/actividades/${anuncio}/exportar-pdf`);
check(r.status === 400, 'los anuncios no se exportan');
r = await req(TM, 'GET', '/exportaciones');
check(r.status === 403, 'el apadrinado no consulta exportaciones');

console.log('\n== Expediente, historial y gestión documental');
r = await req(TC, 'POST', `/expedientes/apadrinado/${SM.apadrinadoId}/observaciones`, { texto: 'Muy participativa' });
check(r.status === 201, 'agregar observación al expediente');
r = await req(TC, 'GET', `/expedientes/apadrinado/${SM.apadrinadoId}`);
check(r.data.apadrinado.telefono === '5555-0101' && r.data.fotografias.length >= 1 && r.data.cartas.length >= 1
  && r.data.observaciones.length >= 2 && r.data.totalAprobadas === 1,
  'expediente con datos personales, fotos, cartas, observaciones y aprobadas', r.data);
r = await req(TC, 'GET', `/expedientes/apadrinado/${SM.apadrinadoId}/historial`);
const acciones = new Set(r.data.map((h) => h.accion));
for (const a of ['SOLICITUD ACEPTADA', 'ACTIVIDAD ASIGNADA', 'ENTREGA ENVIADA', 'CORRECCIÓN SOLICITADA',
  'ENTREGA APROBADA', 'EXPORTACIÓN PDF APADRINADO', 'OBSERVACIÓN REGISTRADA']) {
  check(acciones.has(a), 'historial: ' + a);
}
r = await req(TC, 'GET', `/documentos/apadrinado/${SM.apadrinadoId}?tipo=FOTOGRAFIA&estado=APROBADA`);
check(r.data.length === 1 && r.data[0].nombreOriginal === 'familia_nitida.png', 'gestión documental filtrada por tipo y estado', r.data);

console.log('\n== Eliminación');
r = await req(TC, 'DELETE', `/actividades/${tarea}`);
check(r.status === 409, 'eliminar una actividad con entregas pide confirmación');
r = await req(TC, 'DELETE', `/actividades/${tarea}?confirmar=true`);
check(r.data.eliminacion === 'LOGICA', 'eliminación lógica');
r = await req(TM, 'GET', '/asignaciones/mias');
check(!r.data.some((s) => s.actividadId === tarea), 'la actividad eliminada deja de mostrarse al apadrinado');
r = await req(TC, 'GET', `/expedientes/apadrinado/${SM.apadrinadoId}`);
check(r.data.actividades.some((s) => s.actividadId === tarea), 'pero se conserva en el expediente');
r = await req(TC, 'DELETE', `/actividades/${anuncio}`);
check(r.data.eliminacion === 'DEFINITIVA', 'un anuncio sin entregas se elimina definitivamente', r.data);
r = await req(TC, 'GET', `/comunidades/${com}/historial`);
check(r.data.some((h) => h.accion === 'ACTIVIDAD ELIMINADA' && h.referencia === 'Reunión el sábado'), 'la eliminación queda en el historial');
r = await req(TC, 'DELETE', `/modulos/${mod2}`);
check(r.status === 400 && /Muévalas/.test(r.data.message), 'no se elimina un módulo con actividades');

console.log(`\nResultado: ${ok} correctas, ${fail} fallidas`);
process.exit(fail ? 1 : 0);
