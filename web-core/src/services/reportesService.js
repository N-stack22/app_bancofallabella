import { cachedGet } from './api.js'

/** Reporte historico de productividad por asesor. GET /reportes/productividad */
export async function productividad(filters = {}) {
  const params = Object.fromEntries(
    Object.entries(filters).filter(([, value]) => value !== undefined && value !== null && value !== ''),
  )
  return cachedGet('/reportes/productividad', { params }, 45000)
}
