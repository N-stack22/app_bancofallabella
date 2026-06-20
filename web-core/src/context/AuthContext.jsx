import { createContext, useContext, useState, useCallback, useMemo } from 'react'
import * as authService from '../services/authService.js'

// Contexto de autenticación del asesor (portal del personal).
const AuthContext = createContext(null)

export function AuthProvider({ children }) {
  const demoUser = {
    nombre: 'Nathalie Tatiana Rodriguez Rios',
    nombres: 'Nathalie Tatiana',
    codigo_empleado: 'BF-CORE',
    perfil: 'Operador',
  }
  const [token, setToken] = useState(() => authService.getStoredToken() || 'demo-falabella')
  const [user, setUser] = useState(() => authService.getStoredUser() || demoUser)

  const login = useCallback(async (codigoEmpleado, password) => {
    const { token: newToken, user: newUser } = await authService.login(codigoEmpleado, password)
    authService.saveSession(newToken, newUser)
    setToken(newToken)
    setUser(newUser)
    return newUser
  }, [])

  const logout = useCallback(() => {
    authService.clearSession()
    setToken('demo-falabella')
    setUser(demoUser)
  }, [])

  const value = useMemo(
    () => ({
      user,
      token,
      isAuthenticated: Boolean(token),
      login,
      logout,
    }),
    [user, token, login, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth debe usarse dentro de <AuthProvider>')
  return ctx
}

export default useAuth
