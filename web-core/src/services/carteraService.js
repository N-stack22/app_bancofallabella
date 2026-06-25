import api, { cachedGet, invalidateApiCache } from './api.js'

/** Cartera del día del asesor autenticado. GET /cartera?fecha=YYYY-MM-DD */
export async function listarCartera(fecha) {
  const params = fecha ? { fecha } : {}
  return cachedGet('/cartera', { params }, 45000)
}

/** Registra el resultado de una visita. POST /cartera/{id}/visita */
export async function marcarVisita(carteraId, payload) {
  const { data } = await api.post(`/cartera/${carteraId}/visita`, payload)
  invalidateApiCache('/cartera')
  return data
}
