import { cachedGet } from './api.js'

/** Reporte de productividad mensual por asesor. GET /reportes/productividad */
export async function productividad() {
  return cachedGet('/reportes/productividad', {}, 45000)
}
