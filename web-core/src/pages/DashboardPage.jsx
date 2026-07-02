import { useState, useEffect } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Briefcase, FileText, ShieldCheck, HandCoins, BarChart3, MapPin,
  CheckCircle2, AlertTriangle, TrendingUp, ArrowRight, PlusCircle,
  Database, Server, CreditCard, Landmark,
} from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import Money from '../components/ui/Money.jsx'
import { useAuth } from '../context/AuthContext.jsx'
import { listarCartera } from '../services/carteraService.js'
import { listarSolicitudes } from '../services/solicitudesService.js'
import { diagnosticoConexion, resumenCasos } from '../services/casosService.js'
import { extractError, formatDateTime } from '../utils/format.js'

const ACCESOS = [
  { to: '/cartera', icon: Briefcase, color: '#007a3d', t: 'Clientes asignados', d: 'Prioridad, ficha y visita del dia' },
  { to: '/solicitudes/nueva', icon: PlusCircle, color: '#0f766e', t: 'Crear solicitud', d: 'Nuevo credito para un cliente real' },
  { to: '/solicitudes', icon: FileText, color: '#004f2a', t: 'Seguimiento', d: 'Comite, estado y desembolso' },
  { to: '/evaluacion', icon: ShieldCheck, color: '#2563eb', t: 'Riesgo', d: 'Pre-evaluacion, buro y politicas' },
  { to: '/cobranza', icon: HandCoins, color: '#b76a00', t: 'Cobranza', d: 'Mora, compromiso y pagos' },
  { to: '/reportes', icon: BarChart3, color: '#168a46', t: 'Reportes', d: 'Productividad y colocacion' },
]

const FLUJO_ROL = [
  { icon: Briefcase, title: '1. Identificar cliente', text: 'Revisa cartera y prioridad antes de abrir ficha.' },
  { icon: ShieldCheck, title: '2. Evaluar riesgo', text: 'Valida buro, capacidad y monto recomendado.' },
  { icon: FileText, title: '3. Decidir solicitud', text: 'Registra comite y desembolso cuando corresponda.' },
  { icon: HandCoins, title: '4. Acompanar cartera', text: 'Confirma movimientos, pagos y cobranza.' },
]

const PRODUCTOS_BF = [
  { icon: Landmark, t: 'Cuenta Banco Falabella', d: 'Ahorros, movimientos y pagos desde App/Banca por Internet.' },
  { icon: CreditCard, t: 'Tarjeta CMR Visa', d: 'Linea, pagos y relacion comercial del cliente.' },
  { icon: HandCoins, t: 'Prestamo Efectivo / Rapicash', d: 'Oferta, evaluacion, desembolso y cronograma.' },
]

export default function DashboardPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const [cartera, setCartera] = useState([])
  const [solicitudes, setSolicitudes] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [conexion, setConexion] = useState(null)
  const [casos, setCasos] = useState(null)

  useEffect(() => {
    let alive = true
    Promise.allSettled([listarCartera(), listarSolicitudes(), diagnosticoConexion(), resumenCasos()])
      .then(([c, s, cnx, resumen]) => {
        if (!alive) return
        if (c.status === 'fulfilled') setCartera(c.value || [])
        if (s.status === 'fulfilled') setSolicitudes(s.value || [])
        if (cnx.status === 'fulfilled') setConexion(cnx.value)
        if (resumen.status === 'fulfilled') setCasos(resumen.value)
        if (c.status === 'rejected' && s.status === 'rejected') {
          setError(extractError(c.reason, 'No se pudieron cargar los datos.'))
        }
      })
      .finally(() => alive && setLoading(false))
    return () => { alive = false }
  }, [])

  const pendientes = cartera.filter((c) => c.estado_visita === 'pendiente').length
  const visitados = cartera.filter((c) => c.estado_visita && c.estado_visita !== 'pendiente').length
  const montoCartera = cartera.reduce((acc, c) => acc + (c.monto_credito || 0), 0)
  const aprobadas = solicitudes.filter((s) => ['aprobado', 'desembolsado'].includes(s.estado)).length

  return (
    <>
      <PageHead
        title={`Hola, ${user?.nombres || 'asesor'}`}
        subtitle="Panel operativo Banco Falabella: cartera, originacion, comite y desembolso."
      />

      {error && <Alert tipo="error">{error}</Alert>}

      {loading ? (
        <Loader text="Cargando tu panel..." />
      ) : (
        <>
          <div className="cm-kpis">
            <div className="cm-kpi">
              <span className="cm-kpi-ico" style={{ background: '#e6f3ec', color: '#007a3d' }}><MapPin size={24} /></span>
              <div>
                <div className="cm-kpi-label">Visitas pendientes</div>
                <span className="cm-kpi-val">{pendientes}</span>
                <small>de {cartera.length} en cartera</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#00a9a5' }}>
              <span className="cm-kpi-ico" style={{ background: '#e6f7f6', color: '#00a9a5' }}><CheckCircle2 size={24} /></span>
              <div>
                <div className="cm-kpi-label">Gestionadas hoy</div>
                <span className="cm-kpi-val">{visitados}</span>
                <small>visitas registradas</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#f7941e' }}>
              <span className="cm-kpi-ico" style={{ background: '#fef3e2', color: '#f7941e' }}><TrendingUp size={24} /></span>
              <div>
                <div className="cm-kpi-label">Monto en cartera</div>
                <span className="cm-kpi-val" style={{ fontSize: 20 }}><Money value={montoCartera} /></span>
                <small>colocacion gestionada</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#8e24aa' }}>
              <span className="cm-kpi-ico" style={{ background: '#f3e6f7', color: '#8e24aa' }}><FileText size={24} /></span>
              <div>
                <div className="cm-kpi-label">Solicitudes aprobadas</div>
                <span className="cm-kpi-val">{aprobadas}</span>
                <small>de {solicitudes.length} historicas</small>
              </div>
            </div>
          </div>

          <h2 className="cm-section-title">Conexion del ecosistema</h2>
          <div className="cm-kpis">
            <div className="cm-kpi">
              <span className="cm-kpi-ico" style={{ background: '#e0f2e7', color: '#007a3d' }}><Server size={24} /></span>
              <div>
                <div className="cm-kpi-label">Core / API REST</div>
                <span className="cm-kpi-val">{conexion?.api || '...'}</span>
                <small>Verificado {formatDateTime(conexion?.fecha_hora)}</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#00a9a5' }}>
              <span className="cm-kpi-ico" style={{ background: '#e6f7f6', color: '#00a9a5' }}><Database size={24} /></span>
              <div>
                <div className="cm-kpi-label">Base de datos</div>
                <span className="cm-kpi-val">{conexion?.bd_core_mobile || 'offline'}</span>
                <small>bd_core_mobile + sync_outbox</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#f7941e' }}>
              <span className="cm-kpi-ico" style={{ background: '#fef3e2', color: '#f7941e' }}><FileText size={24} /></span>
              <div>
                <div className="cm-kpi-label">Casos PDF</div>
                <span className="cm-kpi-val">{casos?.total_casos || 30}</span>
                <small>24 desembolsados, 3 condicionados, 3 rechazados</small>
              </div>
            </div>
            <div className="cm-kpi" style={{ borderLeftColor: '#8e24aa' }}>
              <span className="cm-kpi-ico" style={{ background: '#f3e6f7', color: '#8e24aa' }}><TrendingUp size={24} /></span>
              <div>
                <div className="cm-kpi-label">Monto aprobado</div>
                <span className="cm-kpi-val" style={{ fontSize: 20 }}><Money value={casos?.monto_aprobado || 0} /></span>
                <small>sobre el catalogo completo</small>
              </div>
            </div>
          </div>

          <h2 className="cm-section-title">Productos y servicios cubiertos</h2>
          <div className="cm-quick-grid" style={{ marginBottom: 22 }}>
            {PRODUCTOS_BF.map((p) => {
              const Icon = p.icon
              return (
                <div key={p.t} className="cm-quick" style={{ cursor: 'default' }}>
                  <span className="cm-quick-ico" style={{ background: '#e6f3ec', color: '#007a3d' }}>
                    <Icon size={24} />
                  </span>
                  <div>
                    <h3>{p.t}</h3>
                    <p>{p.d}</p>
                  </div>
                </div>
              )
            })}
          </div>

          <h2 className="cm-section-title">Flujo por rol</h2>
          <div className="cm-flow-grid">
            {FLUJO_ROL.map((step) => {
              const Icon = step.icon
              return (
                <div className="cm-flow-step" key={step.title}>
                  <span><Icon size={18} /></span>
                  <strong>{step.title}</strong>
                  <small>{step.text}</small>
                </div>
              )
            })}
          </div>

          <h2 className="cm-section-title">Accesos rapidos</h2>
          <div className="cm-quick-grid">
            {ACCESOS.map((a) => {
              const Icon = a.icon
              return (
                <button key={a.to} className="cm-quick" onClick={() => navigate(a.to)}>
                  <span className="cm-quick-ico" style={{ background: `${a.color}1a`, color: a.color }}>
                    <Icon size={24} />
                  </span>
                  <div style={{ flex: 1 }}>
                    <h3>{a.t}</h3>
                    <p>{a.d}</p>
                  </div>
                  <ArrowRight size={18} color="#9ca3af" />
                </button>
              )
            })}
          </div>

          {pendientes > 0 && (
            <Card title="Proxima visita prioritaria" icon={AlertTriangle} style={{ marginTop: 22 }}>
              {(() => {
                const top = [...cartera]
                  .filter((c) => c.estado_visita === 'pendiente')
                  .sort((a, b) => (b.score_prioridad || 0) - (a.score_prioridad || 0))[0]
                if (!top) return null
                return (
                  <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 16, flexWrap: 'wrap' }}>
                    <div>
                      <strong style={{ fontSize: 16 }}>{top.cliente_nombre}</strong>
                      <div style={{ color: 'var(--hb-muted)', fontSize: 13 }}>
                        DNI {top.documento} - Prioridad {top.prioridad} (score {top.score_prioridad})
                      </div>
                    </div>
                    <button className="hb-btn" onClick={() => navigate('/cartera')}>
                      Ir a la cartera <ArrowRight size={16} />
                    </button>
                  </div>
                )
              })()}
            </Card>
          )}
        </>
      )}
    </>
  )
}
