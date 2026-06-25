import { createContext, useContext, useState, useCallback, useMemo } from 'react'
import * as authService from '../services/authService.js'

// Contexto de autenticación del asesor (portal del personal).
const AuthContext = createContext(null)

function getInitialToken() {
  const token = authService.getStoredToken()
  if (token === 'demo-falabella') {
    authService.clearSession()
    return null
  }
  return token
}

function getInitialUser() {
  if (authService.getStoredToken() === 'demo-falabella') {
    authService.clearSession()
    return null
  }
  return authService.getStoredUser()
}

export function AuthProvider({ children }) {
  const [token, setToken] = useState(() => getInitialToken())
  const [user, setUser] = useState(() => getInitialUser())

  const login = useCallback(async (codigoEmpleado, password) => {
    const { token: newToken, user: newUser } = await authService.login(codigoEmpleado, password)
    authService.saveSession(newToken, newUser)
    setToken(newToken)
    setUser(newUser)
    return newUser
  }, [])

  const logout = useCallback(() => {
    authService.clearSession()
    setToken(null)
    setUser(null)
  }, [])

  const value = useMemo(
    () => ({
      user,
      token,
      isAuthenticated: Boolean(token && user),
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
