import api, { cachedGet } from './api.js'

/** Lista clientes/prospectos del core. GET /clientes */
export async function listarClientes(filters = {}) {
  const params = Object.fromEntries(
    Object.entries(filters).filter(([, value]) => value !== undefined && value !== null && value !== ''),
  )
  return cachedGet('/clientes', { params }, 45000)
}

/** Ficha completa del cliente. GET /clientes/{cliente_id}/ficha */
export async function obtenerFicha(clienteId) {
  const { data } = await api.get(`/clientes/${clienteId}/ficha`)
  return data
}
