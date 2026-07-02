import { Navigate, useLocation } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext.jsx'
import { hasRole } from '../../utils/roles.js'

export default function PrivateRoute({ children, roles = [] }) {
  const { isAuthenticated, user } = useAuth()
  const location = useLocation()

  if (!isAuthenticated) {
    return <Navigate to="/login" replace state={{ from: location.pathname }} />
  }
  if (!hasRole(user, roles)) {
    return <Navigate to="/inicio" replace />
  }
  return children
}
