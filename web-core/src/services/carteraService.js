import api, { cachedGet, invalidateApiCache, isDemoSession } from './api.js'

/** Cartera del día del asesor autenticado. GET /cartera?fecha=YYYY-MM-DD */
export async function listarCartera(fecha) {
  const params = fecha ? { fecha } : {}
  if (isDemoSession()) {
    return cachedGet('/cartera/demo', { params }, 45000)
  }
  try {
    return await cachedGet('/cartera', { params }, 45000)
  } catch (_) {
    return cachedGet('/cartera/demo', { params }, 45000)
  }
}

/** Registra el resultado de una visita. POST /cartera/{id}/visita */
export async function marcarVisita(carteraId, payload) {
  try {
    const endpoint = isDemoSession()
      ? `/cartera/demo/${carteraId}/visita`
      : `/cartera/${carteraId}/visita`
    const { data } = await api.post(endpoint, payload)
    invalidateApiCache('/cartera')
    return data
  } catch (_) {
    const { data } = await api.post(`/cartera/demo/${carteraId}/visita`, payload)
    invalidateApiCache('/cartera')
    return data
  }
}
