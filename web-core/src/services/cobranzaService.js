import api, { cachedGet, invalidateApiCache } from './api.js'

/** Listado de mora diaria. GET /cobranza/mora */
export async function listarMora() {
  return cachedGet('/cobranza/mora', {}, 45000)
}

/** Registra una gestión de cobranza. POST /cobranza/accion */
export async function registrarAccion(payload) {
  const { data } = await api.post('/cobranza/accion', payload)
  invalidateApiCache('/cobranza')
  return data
}
