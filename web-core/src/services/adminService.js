import api, { cachedGet, invalidateApiCache } from './api.js'

export function listarUsuarios() {
  return cachedGet('/admin/usuarios', {}, 30000)
}

export function crearUsuario(payload) {
  return api.post('/admin/usuarios', payload).then(({ data }) => {
    invalidateApiCache('/admin/usuarios')
    return data
  })
}

export function listarAgencias() {
  return cachedGet('/admin/agencias', {}, 60000)
}

export function crearAgencia(payload) {
  return api.post('/admin/agencias', payload).then(({ data }) => {
    invalidateApiCache('/admin/agencias')
    return data
  })
}

export function listarCatalogos() {
  return cachedGet('/admin/catalogos', {}, 60000)
}

export function crearCatalogo(payload) {
  return api.post('/admin/catalogos', payload).then(({ data }) => {
    invalidateApiCache('/admin/catalogos')
    return data
  })
}
