import { useEffect, useState } from 'react'
import { Database, RefreshCw, Server, UploadCloud } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import {
  diagnosticoConexion,
  listarCasos,
  resumenCasos,
  sembrarCasos,
} from '../services/casosService.js'
import { formatDateTime } from '../utils/format.js'

export default function CasosPage() {
  const [casos, setCasos] = useState([])
  const [resumen, setResumen] = useState(null)
  const [conexion, setConexion] = useState(null)
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [message, setMessage] = useState(null)

  const load = async () => {
    setLoading(true)
    setMessage(null)
    try {
      const [rows, stats, health] = await Promise.allSettled([
        listarCasos(),
        resumenCasos(),
        diagnosticoConexion(),
      ])
      if (rows.status === 'fulfilled') setCasos(rows.value)
      if (stats.status === 'fulfilled') setResumen(stats.value)
      if (health.status === 'fulfilled') setConexion(health.value)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => { load() }, [])

  const seed = async () => {
    setSaving(true)
    setMessage(null)
    try {
      const result = await sembrarCasos()
      setMessage({ type: result.ok ? 'success' : 'warn', text: `Creados ${result.creados || 0}, omitidos ${result.omitidos || 0}.` })
      await load()
    } catch (error) {
      setMessage({ type: 'error', text: error?.message || 'No se pudo sembrar.' })
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      <PageHead
        title="Casos de credito del PDF"
        subtitle="Flujo Banco Falabella: App Clientes, Core, Fuerza de Ventas, comite y desembolso."
      />

      {message && <Alert tipo={message.type}>{message.text}</Alert>}

      <div className="cm-kpis">
        <div className="cm-kpi">
          <span className="cm-kpi-ico" style={{ background: '#e0f2e7', color: '#007a3d' }}><Server size={24} /></span>
          <div>
            <div className="cm-kpi-label">API REST</div>
            <span className="cm-kpi-val">{conexion?.api || '...'}</span>
            <small>Verificado {formatDateTime(conexion?.fecha_hora)}</small>
          </div>
        </div>
        <div className="cm-kpi" style={{ borderLeftColor: '#00a9a5' }}>
          <span className="cm-kpi-ico" style={{ background: '#e6f7f6', color: '#00a9a5' }}><Database size={24} /></span>
          <div>
            <div className="cm-kpi-label">Base mobile</div>
            <span className="cm-kpi-val">{conexion?.bd_core_mobile || 'sin conexion'}</span>
            <small>PostgreSQL bd_core_mobile</small>
          </div>
        </div>
        <div className="cm-kpi" style={{ borderLeftColor: '#f7941e' }}>
          <span className="cm-kpi-ico" style={{ background: '#fef3e2', color: '#f7941e' }}><UploadCloud size={24} /></span>
          <div>
            <div className="cm-kpi-label">Casos PDF</div>
            <span className="cm-kpi-val">{resumen?.total_casos || casos.length}</span>
            <small>24 desembolsados, 3 condicionados, 3 rechazados</small>
          </div>
        </div>
        <div className="cm-kpi" style={{ borderLeftColor: '#8e24aa' }}>
          <span className="cm-kpi-ico" style={{ background: '#f3e6f7', color: '#8e24aa' }}><RefreshCw size={24} /></span>
          <div>
            <div className="cm-kpi-label">Outbox</div>
            <span className="cm-kpi-val">{conexion?.core_financiero || 'sync'}</span>
            <small>Puente al nucleo financiero</small>
          </div>
        </div>
      </div>

      <Card title="Catalogo y siembra" icon={Database}>
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, flexWrap: 'wrap', marginBottom: 16 }}>
          <div>
            <strong>Banco Falabella - 30 expedientes</strong>
            <div style={{ color: 'var(--hb-muted)', fontSize: 13 }}>
              La siembra crea clientes, solicitudes, cartera diaria, buro simulado y sync_outbox.
            </div>
          </div>
          <button className="hb-btn" onClick={seed} disabled={saving}>
            <UploadCloud size={16} /> {saving ? 'Sembrando...' : 'Sembrar 30 casos'}
          </button>
        </div>

        {loading ? <Loader text="Cargando casos..." /> : (
          <div className="hb-table-wrap">
            <table className="hb-table">
              <thead>
                <tr>
                  <th>Caso</th>
                  <th>Cliente</th>
                  <th>DNI</th>
                  <th>Negocio</th>
                  <th className="num">Solicitado</th>
                  <th className="num">Aprobado</th>
                  <th>Decision</th>
                  <th>Buro</th>
                </tr>
              </thead>
              <tbody>
                {casos.map((c) => (
                  <tr key={c.caso}>
                    <td>#{String(c.caso).padStart(2, '0')}</td>
                    <td>{c.nombres} {c.apellidos}</td>
                    <td>{c.numero_documento}</td>
                    <td>{c.tipo_negocio} - {c.distrito}</td>
                    <td className="num"><Money value={c.monto_solicitado} /></td>
                    <td className="num"><Money value={c.monto_aprobado} /></td>
                    <td><Badge estado={c.decision_comite} label={c.decision_comite} /></td>
                    <td>{c.calificacion_sbs}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </Card>
    </>
  )
}
