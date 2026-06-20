import api, { cachedGet, invalidateApiCache } from './api.js'

export async function listarCasos() {
  return cachedGet('/casos', {}, 60000)
}

export async function resumenCasos() {
  return cachedGet('/casos/dashboard', {}, 60000)
}

export async function diagnosticoConexion() {
  return cachedGet('/casos/conexion', {}, 15000)
}

export async function sembrarCasos() {
  const { data } = await api.post('/casos/sembrar')
  invalidateApiCache('/casos')
  return data
}
