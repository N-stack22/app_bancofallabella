import { useState, useEffect, useRef } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import {
  LayoutDashboard,
  Briefcase,
  FileText,
  ShieldCheck,
  HandCoins,
  BarChart3,
  Clock,
  ChevronDown,
  LogOut,
  User,
  Database,
  Search,
  Bell,
  Menu,
} from 'lucide-react'
import Logo from '../ui/Logo.jsx'
import { useAuth } from '../../context/AuthContext.jsx'
import { iniciales, humanizar } from '../../utils/format.js'

export const TABS = [
  { to: '/inicio', label: 'Inicio', icon: LayoutDashboard },
  { to: '/cartera', label: 'Cartera', icon: Briefcase },
  { to: '/solicitudes', label: 'Solicitudes', icon: FileText },
  { to: '/evaluacion', label: 'Evaluacion', icon: ShieldCheck },
  { to: '/cobranza', label: 'Cobranza', icon: HandCoins },
  { to: '/reportes', label: 'Reportes', icon: BarChart3 },
  { to: '/casos', label: 'Casos PDF', icon: Database },
]

function Reloj() {
  const [now, setNow] = useState(() => new Date())

  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), 1000)
    return () => clearInterval(id)
  }, [])

  const hh = String(now.getHours()).padStart(2, '0')
  const mm = String(now.getMinutes()).padStart(2, '0')
  const ss = String(now.getSeconds()).padStart(2, '0')

  return (
    <span className="cm-clock">
      <Clock size={15} /> {hh}:{mm}:{ss}
    </span>
  )
}

export default function Header() {
  const navigate = useNavigate()
  const location = useLocation()
  const { user, logout } = useAuth()
  const [menuOpen, setMenuOpen] = useState(false)
  const wrapRef = useRef(null)

  useEffect(() => {
    const onClick = (e) => {
      if (wrapRef.current && !wrapRef.current.contains(e.target)) setMenuOpen(false)
    }
    document.addEventListener('mousedown', onClick)
    return () => document.removeEventListener('mousedown', onClick)
  }, [])

  const onLogout = () => {
    logout()
    navigate('/login', { replace: true })
  }

  return (
    <header className="cm-shell">
      <aside className="cm-sidebar">
        <button className="cm-brand cm-brand-panel" onClick={() => navigate('/inicio')} aria-label="Inicio">
          <Logo size={36} variant="dark" subtitle="CORE OFFICE" />
        </button>

        <nav className="cm-side-tabs" aria-label="Navegacion principal">
          {TABS.map((tab) => {
            const Icon = tab.icon
            const active = location.pathname === tab.to || location.pathname.startsWith(`${tab.to}/`)
            return (
              <button
                key={tab.to}
                className={`cm-side-tab ${active ? 'active' : ''}`}
                onClick={() => navigate(tab.to)}
              >
                <Icon size={18} />
                <span>{tab.label}</span>
              </button>
            )
          })}
        </nav>

        <div className="cm-side-user">
          <span className="cm-avatar">{iniciales(user?.nombre)}</span>
          <div>
            <strong>{user?.nombres || user?.nombre || 'Asesor'}</strong>
            <small>{user?.codigo_empleado}</small>
          </div>
        </div>
      </aside>

      <div className="cm-commandbar">
        <button className="cm-mobile-menu" aria-label="Abrir navegacion">
          <Menu size={19} />
        </button>

        <div className="cm-command-title">
          <span>Portal operativo</span>
          <strong>Banco Falabella</strong>
        </div>

        <div className="cm-command-search" aria-label="Busqueda visual">
          <Search size={16} />
          <span>Buscar cliente, expediente o DNI</span>
        </div>

        <div className="cm-topbar-right">
          <Reloj />
          <button className="cm-icon-action" aria-label="Notificaciones">
            <Bell size={17} />
          </button>
          <div className="cm-user-wrap" ref={wrapRef}>
            <button className="cm-user" onClick={() => setMenuOpen((open) => !open)}>
              <span className="cm-avatar">{iniciales(user?.nombre)}</span>
              <span className="cm-user-text">
                <strong>{user?.nombre || 'Asesor'}</strong>
                <small>{humanizar(user?.perfil)}</small>
              </span>
              <ChevronDown size={16} />
            </button>
            {menuOpen && (
              <div className="cm-user-menu">
                <div className="cm-user-menu-head">
                  <strong>{user?.nombre}</strong>
                  <small>Codigo {user?.codigo_empleado} - {humanizar(user?.perfil)}</small>
                </div>
                <button onClick={() => { setMenuOpen(false); navigate('/inicio') }}>
                  <User size={16} /> Mi panel
                </button>
                <button onClick={onLogout}>
                  <LogOut size={16} /> Cerrar sesion
                </button>
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  )
}
