import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  BadgeCheck,
  BriefcaseBusiness,
  Building2,
  ChartNoAxesCombined,
  CheckCircle2,
  Lock,
  LogIn,
  ShieldCheck,
  User,
} from 'lucide-react'
import Logo from '../components/ui/Logo.jsx'
import Alert from '../components/ui/Alert.jsx'
import { useAuth } from '../context/AuthContext.jsx'
import { extractError } from '../utils/format.js'

const OPERATIONS = [
  { label: 'Clientes activos', value: '30', note: 'casos cargados' },
  { label: 'Expedientes', value: '27', note: 'desembolsados' },
  { label: 'Controles', value: '100%', note: 'buro y documentos' },
]

const ACCESS_POINTS = [
  'Cartera diaria y visita en campo',
  'Evaluacion crediticia y comite',
  'Cobranza, reportes y trazabilidad',
]

export default function LoginPage() {
  const { login, isAuthenticated } = useAuth()
  const navigate = useNavigate()
  const [codigo, setCodigo] = useState('')
  const [password, setPassword] = useState('')
  const [recordar, setRecordar] = useState(true)
  const [error, setError] = useState(null)
  const [loading, setLoading] = useState(false)

  useEffect(() => {
    if (isAuthenticated) navigate('/inicio', { replace: true })
  }, [isAuthenticated, navigate])

  const onSubmit = async (e) => {
    e.preventDefault()
    setError(null)
    if (!codigo.trim() || !password) {
      setError('Ingresa tu DNI y contrasena.')
      return
    }
    setLoading(true)
    try {
      await login(codigo.trim(), password)
      navigate('/inicio', { replace: true })
    } catch (err) {
      setError(extractError(err, 'No se pudo iniciar sesion.'))
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className="cm-login cm-login-office">
      <section className="cm-login-brand">
        <div className="cm-login-brand-head">
          <Logo size={42} variant="dark" subtitle="CORE OFFICE" />
          <span className="cm-login-chip">Supabase + FastAPI</span>
        </div>

        <div className="cm-login-copy">
          <span className="cm-eyebrow">
            <Building2 size={16} /> Portal interno Banco Falabella
          </span>
          <h1>Operacion comercial y crediticia en un solo panel.</h1>
          <p>
            Gestiona clientes, solicitudes, evaluacion, desembolso y seguimiento con
            una vista preparada para trabajo diario.
          </p>
        </div>

        <div className="cm-login-metrics">
          {OPERATIONS.map((item) => (
            <div className="cm-login-metric" key={item.label}>
              <strong>{item.value}</strong>
              <span>{item.label}</span>
              <small>{item.note}</small>
            </div>
          ))}
        </div>

        <div className="cm-login-worklist">
          <div className="cm-worklist-icon">
            <BriefcaseBusiness size={20} />
          </div>
          <div>
            <strong>Flujo operativo habilitado</strong>
            {ACCESS_POINTS.map((point) => (
              <span key={point}>
                <CheckCircle2 size={15} /> {point}
              </span>
            ))}
          </div>
        </div>
      </section>

      <section className="cm-auth cm-auth-office">
        <div className="cm-auth-inner">
          <span className="cm-secure">
            <ShieldCheck size={15} /> Acceso seguro del personal
          </span>
          <h2>Bienvenida</h2>
          <p className="cm-auth-lead">Ingresa con tu DNI o codigo autorizado.</p>

          <Alert tipo="error">{error}</Alert>

          <form onSubmit={onSubmit}>
            <div className="cm-field">
              <label htmlFor="codigo">DNI o codigo</label>
              <div className="cm-input-wrap">
                <User size={18} />
                <input
                  id="codigo"
                  placeholder="Ej. 0001"
                  autoComplete="username"
                  inputMode="numeric"
                  value={codigo}
                  onChange={(e) => setCodigo(e.target.value)}
                  autoFocus
                />
              </div>
            </div>

            <div className="cm-field">
              <label htmlFor="password">Contrasena</label>
              <div className="cm-input-wrap">
                <Lock size={18} />
                <input
                  id="password"
                  type="password"
                  placeholder="Clave asignada"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                />
              </div>
            </div>

            <div className="cm-auth-row">
              <label className="cm-check">
                <input type="checkbox" checked={recordar} onChange={(e) => setRecordar(e.target.checked)} />
                Recordarme
              </label>
              <button type="button" className="cm-link" onClick={(e) => e.preventDefault()}>
                Necesito ayuda
              </button>
            </div>

            <button type="submit" className="cm-submit" disabled={loading}>
              <LogIn size={18} />
              {loading ? 'Ingresando...' : 'Entrar al panel'}
            </button>
          </form>

          <div className="cm-auth-hint">
            <BadgeCheck size={15} />
            <span>
              Usa el codigo y clave asignados en el Core operativo.
            </span>
          </div>
        </div>

        <div className="cm-login-status" aria-hidden="true">
          <ChartNoAxesCombined size={18} />
          Core operativo
        </div>
      </section>
    </div>
  )
}
