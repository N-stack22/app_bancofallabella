import api, { cachedGet, invalidateApiCache } from './api.js'

/** Historial / tablero de solicitudes del asesor. GET /solicitudes */
export async function listarSolicitudes() {
  return cachedGet('/solicitudes', {}, 45000)
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
  const { data } = await api.post(`/solicitudes/${solicitudId}/comite`, payload)
  invalidateApiCache('/solicitudes')
  invalidateApiCache('/cartera')
  return data
}

export async function desembolsarSolicitud(solicitudId, payload = {}) {
  const { data } = await api.post(`/solicitudes/${solicitudId}/desembolso`, payload)
  invalidateApiCache('/solicitudes')
  invalidateApiCache('/cartera')
  return data
}
