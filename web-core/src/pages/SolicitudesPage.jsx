import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import { CheckCircle2, FileText, HandCoins, PlusCircle, RefreshCw, StickyNote, Send, XCircle } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import Modal from '../components/ui/Modal.jsx'
import { useAuth } from '../context/AuthContext.jsx'
import {
  agregarNota, decidirComite, desembolsarSolicitud, listarNotas, listarSolicitudes,
} from '../services/solicitudesService.js'
import { extractError, formatDate, formatDateTime } from '../utils/format.js'
import { hasRole } from '../utils/roles.js'

export default function SolicitudesPage() {
  const navigate = useNavigate()
  const { user } = useAuth()
  const canDecide = hasRole(user, ['comite', 'analista', 'supervisor', 'administrador'])
  const [items, setItems] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [ok, setOk] = useState(null)
  const [savingAction, setSavingAction] = useState(null)
  const [fechaDesde, setFechaDesde] = useState('')
  const [fechaHasta, setFechaHasta] = useState('')

  const [notasDe, setNotasDe] = useState(null)
  const [notas, setNotas] = useState([])
  const [notasLoading, setNotasLoading] = useState(false)
  const [nuevaNota, setNuevaNota] = useState('')
  const [savingNota, setSavingNota] = useState(false)

  const cargar = useCallback(() => {
    setLoading(true)
    setOk(null)
    listarSolicitudes({ fecha_desde: fechaDesde, fecha_hasta: fechaHasta })
      .then((data) => setItems(data || []))
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }, [fechaDesde, fechaHasta])

  useEffect(() => { cargar() }, [cargar])

  const abrirNotas = async (sol) => {
    setNotasDe(sol)
    setNotas([])
    setNuevaNota('')
    setNotasLoading(true)
    try {
      setNotas(await listarNotas(sol.id) || [])
    } catch (err) {
      setError(extractError(err))
    } finally {
      setNotasLoading(false)
    }
  }

  const guardarNota = async () => {
    if (!nuevaNota.trim() || !notasDe) return
    setSavingNota(true)
    try {
      await agregarNota(notasDe.id, nuevaNota.trim())
      setNotas(await listarNotas(notasDe.id) || [])
      setNuevaNota('')
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSavingNota(false)
    }
  }

  const accionComite = async (sol, decision) => {
    setSavingAction(`${sol.id}-${decision}`)
    setError(null)
    try {
      const monto = decision === 'rechazado'
        ? 0
        : (decision === 'condicionado'
          ? Math.round((sol.monto_aprobado || sol.monto_solicitado || 0) * 0.8)
          : (sol.monto_aprobado || sol.monto_solicitado || 0))
      await decidirComite(sol.id, {
        decision,
        monto_aprobado: monto,
        condicion_adicional: decision === 'condicionado' ? 'Monto reducido por comite.' : null,
        motivo_rechazo: decision === 'rechazado' ? 'No cumple politica de riesgo.' : null,
      })
      setOk(`${sol.numero_expediente} actualizado a ${decision}.`)
      await listarSolicitudes({ fecha_desde: fechaDesde, fecha_hasta: fechaHasta }).then((data) => setItems(data || []))
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSavingAction(null)
    }
  }

  const accionDesembolso = async (sol) => {
    setSavingAction(`${sol.id}-desembolso`)
    setError(null)
    try {
      await desembolsarSolicitud(sol.id, { observacion: 'Desembolso confirmado desde portal.' })
      setOk(`${sol.numero_expediente} desembolsado y enviado a sync_outbox.`)
      await listarSolicitudes({ fecha_desde: fechaDesde, fecha_hasta: fechaHasta }).then((data) => setItems(data || []))
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSavingAction(null)
    }
  }

  return (
    <>
      <PageHead
        title="Mis solicitudes"
        subtitle="Tablero de estado de tus expedientes de credito"
        icon={FileText}
        actions={
          <>
            <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}><RefreshCw size={15} /> Actualizar</button>
            <button className="hb-btn" onClick={() => navigate('/solicitudes/nueva')}><PlusCircle size={16} /> Nueva</button>
          </>
        }
      />

      {error && <Alert tipo="error">{error}</Alert>}
      {ok && <Alert tipo="success">{ok}</Alert>}

      <div className="hb-card" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12, alignItems: 'end', marginBottom: 16 }}>
        <div className="hb-field" style={{ margin: 0 }}>
          <label>Desde</label>
          <input className="hb-input" type="date" value={fechaDesde} onChange={(e) => setFechaDesde(e.target.value)} />
        </div>
        <div className="hb-field" style={{ margin: 0 }}>
          <label>Hasta</label>
          <input className="hb-input" type="date" value={fechaHasta} onChange={(e) => setFechaHasta(e.target.value)} />
        </div>
        <button
          className="hb-btn hb-btn-gray"
          onClick={() => {
            setFechaDesde('')
            setFechaHasta('')
          }}
        >
          Ver historico completo
        </button>
      </div>

      {loading ? (
        <Loader text="Cargando solicitudes..." />
      ) : items.length === 0 ? (
        <div className="hb-card hb-table-empty">
          No hay solicitudes para el rango seleccionado.
          <div style={{ marginTop: 14 }}>
            <button className="hb-btn" onClick={() => navigate('/solicitudes/nueva')}><PlusCircle size={16} /> Registrar la primera</button>
          </div>
        </div>
      ) : (
        <div className="hb-card" style={{ padding: 0 }}>
          <div className="hb-table-wrap">
            <table className="hb-table">
              <thead>
                <tr>
                  <th>Expediente</th>
                  <th>Cliente</th>
                  <th className="num">Solicitado</th>
                  <th className="num">Aprobado</th>
                  <th>Estado</th>
                  <th>Fecha</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {items.map((s) => (
                  <tr key={s.id}>
                    <td><strong>{s.numero_expediente}</strong></td>
                    <td>{s.cliente_nombre}</td>
                    <td className="num"><Money value={s.monto_solicitado} /></td>
                    <td className="num">{s.monto_aprobado ? <Money value={s.monto_aprobado} /> : '-'}</td>
                    <td><Badge estado={s.estado} /></td>
                    <td>{formatDate(s.created_at)}</td>
                    <td>
                      <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end', flexWrap: 'wrap' }}>
                        {canDecide && s.estado === 'recibido_comite' && (
                          <>
                            <button className="hb-btn hb-btn-sm" onClick={() => accionComite(s, 'aprobado')} disabled={!!savingAction}>
                              <CheckCircle2 size={14} /> Aprobar
                            </button>
                            <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={() => accionComite(s, 'condicionado')} disabled={!!savingAction}>
                              Condicionar
                            </button>
                            <button className="hb-btn hb-btn-ghost hb-btn-sm" onClick={() => accionComite(s, 'rechazado')} disabled={!!savingAction}>
                              <XCircle size={14} /> Rechazar
                            </button>
                          </>
                        )}
                        {canDecide && ['aprobado', 'condicionado'].includes(s.estado) && (
                          <button className="hb-btn hb-btn-sm" onClick={() => accionDesembolso(s)} disabled={!!savingAction}>
                            <HandCoins size={14} /> Desembolsar
                          </button>
                        )}
                        <button className="hb-btn hb-btn-ghost hb-btn-sm" onClick={() => abrirNotas(s)}>
                          <StickyNote size={14} /> Notas
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      )}

      {notasDe && (
        <Modal
          title={`Notas - ${notasDe.numero_expediente}`}
          icon={StickyNote}
          onClose={() => setNotasDe(null)}
        >
          {notasLoading ? (
            <Loader text="Cargando notas..." />
          ) : (
            <>
              <div style={{ display: 'flex', flexDirection: 'column', gap: 10, marginBottom: 16, maxHeight: 240, overflowY: 'auto' }}>
                {notas.length === 0 ? (
                  <p style={{ color: 'var(--hb-muted)', margin: 0, fontSize: 14 }}>Sin notas todavia.</p>
                ) : (
                  notas.map((n, i) => (
                    <div key={i} style={{ background: 'var(--hb-bg)', borderRadius: 10, padding: '10px 12px', border: '1px solid var(--hb-border)' }}>
                      <div style={{ fontSize: 14 }}>{n.contenido}</div>
                      {n.created_at && <small style={{ color: 'var(--hb-muted)' }}>{formatDateTime(n.created_at)}</small>}
                    </div>
                  ))
                )}
              </div>
              <div className="hb-field" style={{ marginBottom: 10 }}>
                <textarea
                  className="hb-textarea"
                  placeholder="Escribe una nota interna..."
                  value={nuevaNota}
                  onChange={(e) => setNuevaNota(e.target.value)}
                />
              </div>
              <button className="hb-btn" onClick={guardarNota} disabled={savingNota || !nuevaNota.trim()}>
                <Send size={15} /> {savingNota ? 'Guardando...' : 'Agregar nota'}
              </button>
            </>
          )}
        </Modal>
      )}
    </>
  )
}
