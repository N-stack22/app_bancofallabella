const ROLE_ALIASES = {
  operador: 'asesor',
  asesor: 'asesor',
  'asesor de negocios': 'asesor',
  comite: 'comite',
  comité: 'comite',
  analista: 'analista',
  supervisor: 'supervisor',
  'super operador': 'supervisor',
  administrador: 'administrador',
  admin: 'administrador',
}

export function normalizeRole(role) {
  const key = String(role || '').trim().toLowerCase()
  return ROLE_ALIASES[key] || key || 'asesor'
}

export function hasRole(user, roles = []) {
  if (!roles.length) return true
  const current = normalizeRole(user?.perfil)
  return roles.map(normalizeRole).includes(current)
}

export function allowedTabs(tabs, user) {
  return tabs.filter((tab) => hasRole(user, tab.roles || []))
}
