import api, { cachedGet, invalidateApiCache, isDemoSession } from './api.js'

/** Historial / tablero de solicitudes del asesor. GET /solicitudes */
export async function listarSolicitudes() {
  if (isDemoSession()) {
    return cachedGet('/solicitudes/demo', {}, 45000)
  }
  try {
    return await cachedGet('/solicitudes', {}, 45000)
  } catch (error) {
    try {
      return await cachedGet('/solicitudes/demo', {}, 45000)
    } catch (_) {
      // Sin Core/autenticacion: deja visible el catalogo del PDF como respaldo.
    }
    const casos = await cachedGet('/casos', {}, 60000)
    return casos.map((c) => ({
      id: c.numero_expediente,
      numero_expediente: c.numero_expediente,
      cliente_nombre: `${c.nombres} ${c.apellidos}`,
      monto_solicitado: c.monto_solicitado,
      monto_aprobado: c.monto_aprobado,
      estado: c.estado_final,
      created_at: '2026-06-17',
    }))
  }
}

/** Crea una solicitud de crédito. POST /solicitudes */
export async function crearSolicitud(payload) {
  const { data } = await api.post('/solicitudes', payload)
  invalidateApiCache('/solicitudes')
  invalidateApiCache('/cartera')
  return data
}

/** Notas internas de una solicitud. GET /solicitudes/{id}/notas */
export async function listarNotas(solicitudId) {
  const { data } = await api.get(`/solicitudes/${solicitudId}/notas`)
  return data
}

/** Agrega una nota interna. POST /solicitudes/{id}/notas */
export async function agregarNota(solicitudId, contenido) {
  const { data } = await api.post(`/solicitudes/${solicitudId}/notas`, { contenido })
  return data
}

export async function decidirComite(solicitudId, payload) {
  const { data } = await api.post(`/solicitudes/demo/${solicitudId}/comite`, payload)
  invalidateApiCache('/solicitudes')
  invalidateApiCache('/cartera')
  return data
}

export async function desembolsarSolicitud(solicitudId, payload = {}) {
  const { data } = await api.post(`/solicitudes/demo/${solicitudId}/desembolso`, payload)
  invalidateApiCache('/solicitudes')
  invalidateApiCache('/cartera')
  return data
}
