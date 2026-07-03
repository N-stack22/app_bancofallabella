import { useState } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { ArrowLeft, PlusCircle, CheckCircle2, UserPlus, Coins } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Alert from '../components/ui/Alert.jsx'
import Money from '../components/ui/Money.jsx'
import { crearSolicitud } from '../services/solicitudesService.js'
import { extractError, formatPct, toNumber } from '../utils/format.js'

const MONEDAS = [{ v: 'PEN', l: 'Soles (S/)' }, { v: 'USD', l: 'Dólares (US$)' }]
const TIPO_CUOTA = [{ v: 'mensual', l: 'Mensual' }, { v: 'quincenal', l: 'Quincenal' }, { v: 'semanal', l: 'Semanal' }]
const GARANTIAS = [
  { v: 'sin_garantia', l: 'Sin garantía' },
  { v: 'aval', l: 'Aval' },
  { v: 'prendaria', l: 'Prendaria' },
  { v: 'hipotecaria', l: 'Hipotecaria' },
]

export default function NuevaSolicitudPage() {
  const navigate = useNavigate()
  const location = useLocation()
  const pre = location.state || {}

  const [f, setF] = useState({
    numero_documento: pre.numero_documento || '',
    nombres: pre.nombres || '',
    apellidos: pre.apellidos || '',
    telefono: pre.telefono || '',
    tipo_negocio: pre.tipo_negocio || '',
    nombre_negocio: pre.nombre_negocio || '',
    ingresos_estimados: '',
    gastos_mensuales: '',
    monto_solicitado: '',
    plazo_meses: '12',
    moneda: 'PEN',
    tipo_cuota: 'mensual',
    garantia: 'sin_garantia',
    destino_credito: '',
  })
  const [error, setError] = useState(null)
  const [done, setDone] = useState(null)
  const [saving, setSaving] = useState(false)

  const set = (k) => (e) => setF((s) => ({ ...s, [k]: e.target.value }))

  const onSubmit = async (e) => {
    e.preventDefault()
    setError(null)
    if (!/^\d{8}$/.test(f.numero_documento.trim())) {
      setError('Ingresa un DNI válido de 8 dígitos.')
      return
    }
    if (toNumber(f.monto_solicitado) <= 0) {
      setError('Ingresa el monto solicitado.')
      return
    }
    setSaving(true)
    try {
      const payload = {
        numero_documento: f.numero_documento.trim(),
        nombres: f.nombres.trim(),
        apellidos: f.apellidos.trim(),
        telefono: f.telefono.trim() || null,
        tipo_negocio: f.tipo_negocio.trim() || null,
        nombre_negocio: f.nombre_negocio.trim() || null,
        ingresos_estimados: f.ingresos_estimados ? toNumber(f.ingresos_estimados) : null,
        gastos_mensuales: f.gastos_mensuales ? toNumber(f.gastos_mensuales) : null,
        monto_solicitado: toNumber(f.monto_solicitado),
        plazo_meses: parseInt(f.plazo_meses, 10),
        moneda: f.moneda,
        tipo_cuota: f.tipo_cuota,
        garantia: f.garantia,
        destino_credito: f.destino_credito.trim() || null,
      }
      const res = await crearSolicitud(payload)
      setDone(res)
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  if (done) {
    return (
      <>
        <PageHead title="Solicitud registrada" icon={CheckCircle2} />
        <Card style={{ borderTop: '5px solid var(--hb-green)' }}>
          <div style={{ display: 'flex', gap: 14, alignItems: 'flex-start' }}>
            <CheckCircle2 size={42} color="var(--hb-green)" style={{ flexShrink: 0 }} />
            <div>
              <h3 style={{ margin: '0 0 4px', color: 'var(--hb-green)' }}>¡Expediente creado!</h3>
              <p style={{ margin: 0, color: 'var(--hb-muted)' }}>
                Expediente <strong>{done.numero_expediente}</strong> · estado <strong>{done.estado}</strong>
              </p>
            </div>
          </div>
          {done.evaluacion_crediticia && (
            <div style={{ marginTop: 18 }}>
              <h4 style={{ margin: '0 0 10px' }}>Evaluacion crediticia y TEA referencial</h4>
              <dl className="cm-dl">
                <div><dt>SBS</dt><dd>{done.evaluacion_crediticia.calificacion_sbs}</dd></div>
                <div><dt>Score</dt><dd>{done.evaluacion_crediticia.score_confianza}/100</dd></div>
                <div><dt>Riesgo</dt><dd>{done.evaluacion_crediticia.perfil_riesgo}</dd></div>
                <div><dt>TEA</dt><dd>{formatPct(done.evaluacion_crediticia.tea_referencial)}</dd></div>
                <div><dt>Monto sugerido</dt><dd><Money value={done.evaluacion_crediticia.monto_aprobado_sugerido} /></dd></div>
                <div><dt>Plazo sugerido</dt><dd>{done.evaluacion_crediticia.plazo_sugerido_meses} meses</dd></div>
                <div><dt>Cuota estimada</dt><dd><Money value={done.evaluacion_crediticia.cuota_estimada} /></dd></div>
                <div><dt>Decision</dt><dd>{done.evaluacion_crediticia.decision}</dd></div>
              </dl>
            </div>
          )}
          <div style={{ display: 'flex', gap: 10, marginTop: 20, flexWrap: 'wrap' }}>
            <button className="hb-btn" onClick={() => navigate('/solicitudes')}>Ver mis solicitudes</button>
            <button className="hb-btn hb-btn-gray" onClick={() => { setDone(null); }}>Registrar otra</button>
          </div>
        </Card>
      </>
    )
  }

  return (
    <>
      <button className="cm-back" onClick={() => navigate(-1)}><ArrowLeft size={16} /> Volver</button>
      <PageHead title="Nueva solicitud de crédito" subtitle="Registra los datos del solicitante y las condiciones." icon={PlusCircle} />

      {error && <Alert tipo="error">{error}</Alert>}

      <form onSubmit={onSubmit}>
        <Card title="Solicitante y negocio" icon={UserPlus}>
          <div className="hb-grid-2">
            <div className="hb-field">
              <label>DNI *</label>
              <input className="hb-input" inputMode="numeric" maxLength={8} placeholder="8 dígitos"
                value={f.numero_documento} onChange={(e) => setF((s) => ({ ...s, numero_documento: e.target.value.replace(/\D/g, '') }))} required />
            </div>
            <div className="hb-field">
              <label>Teléfono</label>
              <input className="hb-input" placeholder="9XXXXXXXX" value={f.telefono} onChange={set('telefono')} />
            </div>
            <div className="hb-field">
              <label>Nombres</label>
              <input className="hb-input" value={f.nombres} onChange={set('nombres')} />
            </div>
            <div className="hb-field">
              <label>Apellidos</label>
              <input className="hb-input" value={f.apellidos} onChange={set('apellidos')} />
            </div>
            <div className="hb-field">
              <label>Tipo de negocio</label>
              <input className="hb-input" placeholder="Ej. bodega, taller…" value={f.tipo_negocio} onChange={set('tipo_negocio')} />
            </div>
            <div className="hb-field">
              <label>Nombre del negocio</label>
              <input className="hb-input" value={f.nombre_negocio} onChange={set('nombre_negocio')} />
            </div>
            <div className="hb-field">
              <label>Ingresos estimados (mensual)</label>
              <input className="hb-input" inputMode="decimal" placeholder="0.00" value={f.ingresos_estimados} onChange={set('ingresos_estimados')} />
            </div>
            <div className="hb-field">
              <label>Gastos mensuales</label>
              <input className="hb-input" inputMode="decimal" placeholder="0.00" value={f.gastos_mensuales} onChange={set('gastos_mensuales')} />
            </div>
          </div>
        </Card>

        <Card title="Condiciones del crédito" icon={Coins} style={{ marginTop: 16 }}>
          <div className="hb-grid-3">
            <div className="hb-field">
              <label>Monto solicitado *</label>
              <input className="hb-input" inputMode="decimal" placeholder="0.00" value={f.monto_solicitado} onChange={set('monto_solicitado')} required />
            </div>
            <div className="hb-field">
              <label>Plazo (meses) *</label>
              <input className="hb-input" inputMode="numeric" value={f.plazo_meses} onChange={set('plazo_meses')} required />
            </div>
            <div className="hb-field">
              <label>Moneda</label>
              <select className="hb-select" value={f.moneda} onChange={set('moneda')}>
                {MONEDAS.map((m) => <option key={m.v} value={m.v}>{m.l}</option>)}
              </select>
            </div>
            <div className="hb-field">
              <label>Tipo de cuota</label>
              <select className="hb-select" value={f.tipo_cuota} onChange={set('tipo_cuota')}>
                {TIPO_CUOTA.map((t) => <option key={t.v} value={t.v}>{t.l}</option>)}
              </select>
            </div>
            <div className="hb-field">
              <label>Garantía</label>
              <select className="hb-select" value={f.garantia} onChange={set('garantia')}>
                {GARANTIAS.map((g) => <option key={g.v} value={g.v}>{g.l}</option>)}
              </select>
            </div>
          </div>
          <div className="hb-field">
            <label>Destino del crédito</label>
            <input className="hb-input" placeholder="Ej. capital de trabajo, compra de mercadería…" value={f.destino_credito} onChange={set('destino_credito')} />
          </div>

          <div style={{ display: 'flex', alignItems: 'center', gap: 12, background: '#eef7ff', border: '1px solid #c9dff7', borderRadius: 10, padding: '12px 16px' }}>
            <Coins size={20} color="#155e75" />
            <span style={{ color: '#155e75', fontWeight: 700 }}>TEA y cuota se calculan en Core segun evaluacion crediticia.</span>
          </div>
        </Card>

        <div style={{ display: 'flex', gap: 10, marginTop: 18 }}>
          <button type="submit" className="hb-btn" disabled={saving}>
            <CheckCircle2 size={16} /> {saving ? 'Registrando…' : 'Registrar solicitud'}
          </button>
          <button type="button" className="hb-btn hb-btn-gray" onClick={() => navigate('/solicitudes')}>Cancelar</button>
        </div>
      </form>
    </>
  )
}
