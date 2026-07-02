import { useState, useEffect, useCallback } from 'react'
import { useNavigate } from 'react-router-dom'
import {
  Briefcase, MapPin, CheckCircle2, FileText, RefreshCw, ClipboardCheck, IdCard, Users, Search,
} from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import Badge from '../components/ui/Badge.jsx'
import Money from '../components/ui/Money.jsx'
import Modal from '../components/ui/Modal.jsx'
import { listarCartera, marcarVisita } from '../services/carteraService.js'
import { listarClientes } from '../services/clientesService.js'
import { extractError, formatDateTime, humanizar } from '../utils/format.js'

const RESULTADOS = [
  { v: 'visitado', l: 'Visitado' },
  { v: 'no_encontrado', l: 'No encontrado' },
  { v: 'reagendado', l: 'Reagendado' },
  { v: 'negocio_cerrado', l: 'Negocio cerrado' },
]

export default function CarteraPage() {
  const navigate = useNavigate()
  const [items, setItems] = useState([])
  const [clientes, setClientes] = useState([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [ok, setOk] = useState(null)
  const [vista, setVista] = useState('clientes')
  const [busqueda, setBusqueda] = useState('')
  const [target, setTarget] = useState(null)
  const [resultado, setResultado] = useState('visitado')
  const [observacion, setObservacion] = useState('')
  const [saving, setSaving] = useState(false)

  const cargar = useCallback(() => {
    setLoading(true)
    setError(null)
    Promise.allSettled([
      listarCartera(),
      listarClientes({ q: busqueda, limit: 300 }),
    ])
      .then(([carteraResult, clientesResult]) => {
        if (carteraResult.status === 'fulfilled') setItems(carteraResult.value || [])
        if (clientesResult.status === 'fulfilled') setClientes(clientesResult.value || [])
        if (carteraResult.status === 'rejected' && clientesResult.status === 'rejected') {
          setError(extractError(clientesResult.reason, 'No se pudieron cargar clientes.'))
        }
      })
      .finally(() => setLoading(false))
  }, [busqueda])

  useEffect(() => { cargar() }, [cargar])

  const abrirGestion = (item) => {
    setTarget(item)
    setResultado('visitado')
    setObservacion('')
  }

  const guardar = async () => {
    if (!target) return
    setSaving(true)
    setError(null)
    try {
      await marcarVisita(target.id, { resultado, observacion })
      setItems((prev) => prev.map((i) => (
        i.id === target.id
          ? { ...i, estado_visita: resultado, timestamp_visita: new Date().toISOString() }
          : i
      )))
      setOk(`Visita de ${target.cliente_nombre} registrada como "${humanizar(resultado)}".`)
      setTarget(null)
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  const pendientes = items.filter((i) => i.estado_visita === 'pendiente').length

  return (
    <>
      <PageHead
        title="Clientes"
        subtitle={vista === 'clientes'
          ? `${clientes.length} clientes/prospectos registrados en el core`
          : `${items.length} clientes asignados - ${pendientes} pendientes de visita`}
        icon={vista === 'clientes' ? Users : Briefcase}
        actions={
          <button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}>
            <RefreshCw size={15} /> Actualizar
          </button>
        }
      />

      {error && <Alert tipo="error">{error}</Alert>}
      {ok && <Alert tipo="success">{ok}</Alert>}

      <div className="hb-card" style={{ display: 'grid', gridTemplateColumns: 'auto auto minmax(220px, 1fr)', gap: 12, alignItems: 'end', marginBottom: 16 }}>
        <button
          className={`hb-btn ${vista === 'clientes' ? '' : 'hb-btn-gray'}`}
          onClick={() => setVista('clientes')}
        >
          <Users size={16} /> Todos los clientes
        </button>
        <button
          className={`hb-btn ${vista === 'cartera' ? '' : 'hb-btn-gray'}`}
          onClick={() => setVista('cartera')}
        >
          <Briefcase size={16} /> Cartera del dia
        </button>
        <div className="hb-field" style={{ margin: 0 }}>
          <label>Buscar cliente</label>
          <div style={{ position: 'relative' }}>
            <Search size={16} style={{ position: 'absolute', left: 12, top: 12, color: 'var(--hb-muted)' }} />
            <input
              className="hb-input"
              style={{ paddingLeft: 36 }}
              placeholder="DNI, nombre o negocio"
              value={busqueda}
              onChange={(e) => setBusqueda(e.target.value)}
            />
          </div>
        </div>
      </div>

      {loading ? (
        <Loader text="Cargando clientes..." />
      ) : vista === 'clientes' ? (
        clientes.length === 0 ? (
          <div className="hb-card hb-table-empty">No hay clientes registrados para el filtro seleccionado.</div>
        ) : (
          <div className="cm-list">
            {clientes.map((cli) => (
              <div className="cm-item" key={cli.id}>
                <span className={`cm-item-prio ${cli.estado_solicitud === 'rechazado' ? 'alta' : 'normal'}`} />
                <div className="cm-item-main">
                  <strong>{cli.cliente_nombre}</strong>
                  <small>
                    <IdCard size={13} /> DNI {cli.numero_documento}
                    <span>-</span>
                    {cli.telefono || 'Sin telefono'}
                    <span>-</span>
                    {cli.nombre_negocio || humanizar(cli.tipo_negocio || 'cliente')}
                  </small>
                </div>
                <div className="cm-item-date">
                  <span>Registro</span>
                  <strong>{formatDateTime(cli.fecha_registro)}</strong>
                  <small>{cli.numero_expediente || 'Sin expediente'}</small>
                </div>
                <div className="cm-item-right">
                  <Badge estado={cli.estado_solicitud || (cli.es_prospecto ? 'prospecto' : 'cliente')} label={humanizar(cli.estado_solicitud || (cli.es_prospecto ? 'prospecto' : 'cliente'))} />
                  <Badge estado={cli.calificacion_sbs || 'NORMAL'} label={`SBS ${cli.calificacion_sbs || 'NORMAL'}`} />
                  <div className="cm-item-monto">
                    <Money value={cli.monto_credito} />
                    <small>referencial</small>
                  </div>
                  <button
                    className="hb-btn hb-btn-ghost hb-btn-sm"
                    onClick={() => navigate(`/clientes/${cli.id}/ficha`)}
                  >
                    <FileText size={15} /> Ficha
                  </button>
                </div>
              </div>
            ))}
          </div>
        )
      ) : items.length === 0 ? (
        <div className="hb-card hb-table-empty">
          No tienes clientes asignados para hoy.
          <div style={{ marginTop: 14 }}>
            <button className="hb-btn" onClick={() => setVista('clientes')}><Users size={16} /> Ver todos los clientes</button>
          </div>
        </div>
      ) : (
        <div className="cm-list">
          {items.map((it) => {
            const prio = String(it.prioridad || '').toLowerCase()
            const gestionado = it.estado_visita && it.estado_visita !== 'pendiente'
            const fechaFlujo = it.timestamp_visita || it.fecha_hora_solicitud || it.fecha_asignacion
            return (
              <div className="cm-item" key={it.id}>
                <span className={`cm-item-prio ${prio}`} />
                <div className="cm-item-main">
                  <strong>{it.cliente_nombre}</strong>
                  <small>
                    <IdCard size={13} /> DNI {it.documento}
                    <span>-</span>
                    {humanizar(it.tipo_gestion)}
                    <span>-</span>
                    <span title="Score de prioridad">score {it.score_prioridad}</span>
                  </small>
                </div>
                <div className="cm-item-date">
                  <span>Fecha y hora</span>
                  <strong>{formatDateTime(fechaFlujo)}</strong>
                  <small>{it.numero_expediente || 'Sin expediente'}</small>
                </div>
                <div className="cm-item-right">
                  <Badge estado={it.prioridad} label={`Prioridad ${humanizar(it.prioridad)}`} />
                  {gestionado
                    ? <Badge estado={it.estado_visita} />
                    : <Badge estado="pendiente" tone="amber" label="Pendiente" />}
                  <div className="cm-item-monto">
                    <Money value={it.monto_credito} />
                    <small>credito</small>
                  </div>
                  <div style={{ display: 'flex', gap: 8 }}>
                    <button
                      className="hb-btn hb-btn-ghost hb-btn-sm"
                      onClick={() => navigate(`/clientes/${it.cliente_id}/ficha`)}
                    >
                      <FileText size={15} /> Ficha
                    </button>
                    <button
                      className="hb-btn hb-btn-sm"
                      onClick={() => abrirGestion(it)}
                      disabled={gestionado}
                    >
                      <ClipboardCheck size={15} /> {gestionado ? 'Gestionado' : 'Registrar'}
                    </button>
                  </div>
                </div>
              </div>
            )
          })}
        </div>
      )}

      {target && (
        <Modal
          title={`Registrar visita - ${target.cliente_nombre}`}
          icon={MapPin}
          onClose={() => setTarget(null)}
          footer={
            <>
              <button className="hb-btn hb-btn-gray" onClick={() => setTarget(null)}>Cancelar</button>
              <button className="hb-btn" onClick={guardar} disabled={saving}>
                <CheckCircle2 size={16} /> {saving ? 'Guardando...' : 'Guardar'}
              </button>
            </>
          }
        >
          <div className="hb-field">
            <label>Resultado de la visita</label>
            <div className="cm-chips">
              {RESULTADOS.map((r) => (
                <button
                  key={r.v}
                  type="button"
                  className={`cm-chip ${resultado === r.v ? 'sel' : ''}`}
                  onClick={() => setResultado(r.v)}
                >
                  {r.l}
                </button>
              ))}
            </div>
          </div>
          <div className="hb-field" style={{ marginBottom: 0 }}>
            <label htmlFor="obs">Observacion</label>
            <textarea
              id="obs"
              className="hb-textarea"
              placeholder="Detalle de la gestion (opcional)..."
              value={observacion}
              onChange={(e) => setObservacion(e.target.value)}
            />
          </div>
        </Modal>
      )}
    </>
  )
}
