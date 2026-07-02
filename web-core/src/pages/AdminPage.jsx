import { useCallback, useEffect, useState } from 'react'
import { Building2, PlusCircle, RefreshCw, Tags, UserCog } from 'lucide-react'
import PageHead from '../components/layout/PageHead.jsx'
import Card from '../components/ui/Card.jsx'
import Loader from '../components/ui/Loader.jsx'
import Alert from '../components/ui/Alert.jsx'
import {
  crearAgencia,
  crearCatalogo,
  crearUsuario,
  listarAgencias,
  listarCatalogos,
  listarUsuarios,
} from '../services/adminService.js'
import { extractError, humanizar } from '../utils/format.js'

const ROLES = ['asesor', 'comite', 'analista', 'supervisor', 'administrador']

export default function AdminPage() {
  const [usuarios, setUsuarios] = useState([])
  const [agencias, setAgencias] = useState([])
  const [catalogos, setCatalogos] = useState([])
  const [loading, setLoading] = useState(true)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState(null)
  const [ok, setOk] = useState(null)
  const [usuario, setUsuario] = useState({
    codigo_empleado: '',
    nombres: '',
    apellidos: '',
    agencia_id: '',
    perfil: 'asesor',
    password: '',
    activo: true,
  })
  const [agencia, setAgencia] = useState({ cod_agencia: '', nombre: '', region: '', activa: true })
  const [catalogo, setCatalogo] = useState({ tipo: 'producto', codigo: '', nombre: '', activo: true })

  const cargar = useCallback(() => {
    setLoading(true)
    setError(null)
    Promise.all([listarUsuarios(), listarAgencias(), listarCatalogos()])
      .then(([u, a, c]) => {
        setUsuarios(u || [])
        setAgencias(a || [])
        setCatalogos(c || [])
      })
      .catch((err) => setError(extractError(err)))
      .finally(() => setLoading(false))
  }, [])

  useEffect(() => { cargar() }, [cargar])

  const guardarUsuario = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    try {
      await crearUsuario({ ...usuario, agencia_id: usuario.agencia_id || null })
      setUsuario({ codigo_empleado: '', nombres: '', apellidos: '', agencia_id: '', perfil: 'asesor', password: '', activo: true })
      setOk('Usuario creado.')
      cargar()
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  const guardarAgencia = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    try {
      await crearAgencia(agencia)
      setAgencia({ cod_agencia: '', nombre: '', region: '', activa: true })
      setOk('Agencia creada.')
      cargar()
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  const guardarCatalogo = async (e) => {
    e.preventDefault()
    setSaving(true)
    setError(null)
    try {
      await crearCatalogo({ ...catalogo, valor_json: {} })
      setCatalogo({ tipo: 'producto', codigo: '', nombre: '', activo: true })
      setOk('Catalogo creado.')
      cargar()
    } catch (err) {
      setError(extractError(err))
    } finally {
      setSaving(false)
    }
  }

  return (
    <>
      <PageHead
        title="Administracion"
        subtitle="Usuarios, perfiles, agencias y catalogos institucionales"
        icon={UserCog}
        actions={<button className="hb-btn hb-btn-gray hb-btn-sm" onClick={cargar}><RefreshCw size={15} /> Actualizar</button>}
      />
      {error && <Alert tipo="error">{error}</Alert>}
      {ok && <Alert tipo="success">{ok}</Alert>}
      {loading ? <Loader text="Cargando administracion..." /> : (
        <>
          <Card title="Usuarios y roles" icon={UserCog}>
            <form onSubmit={guardarUsuario} className="hb-grid-3">
              <input className="hb-input" placeholder="Codigo empleado" value={usuario.codigo_empleado} onChange={(e) => setUsuario((s) => ({ ...s, codigo_empleado: e.target.value }))} required />
              <input className="hb-input" placeholder="Nombres" value={usuario.nombres} onChange={(e) => setUsuario((s) => ({ ...s, nombres: e.target.value }))} required />
              <input className="hb-input" placeholder="Apellidos" value={usuario.apellidos} onChange={(e) => setUsuario((s) => ({ ...s, apellidos: e.target.value }))} required />
              <select className="hb-select" value={usuario.agencia_id} onChange={(e) => setUsuario((s) => ({ ...s, agencia_id: e.target.value }))}>
                <option value="">Sin agencia</option>
                {agencias.map((a) => <option key={a.id} value={a.id}>{a.nombre}</option>)}
              </select>
              <select className="hb-select" value={usuario.perfil} onChange={(e) => setUsuario((s) => ({ ...s, perfil: e.target.value }))}>
                {ROLES.map((r) => <option key={r} value={r}>{humanizar(r)}</option>)}
              </select>
              <input className="hb-input" placeholder="Password inicial" value={usuario.password} onChange={(e) => setUsuario((s) => ({ ...s, password: e.target.value }))} />
              <button className="hb-btn" disabled={saving}><PlusCircle size={16} /> Crear usuario</button>
            </form>
            <SimpleTable
              columns={['Codigo', 'Nombre', 'Perfil', 'Agencia', 'Activo']}
              rows={usuarios.map((u) => [
                u.codigo_empleado,
                `${u.nombres} ${u.apellidos}`,
                humanizar(u.perfil),
                u.agencia || '-',
                u.activo ? 'Si' : 'No',
              ])}
            />
          </Card>

          <Card title="Agencias" icon={Building2} style={{ marginTop: 16 }}>
            <form onSubmit={guardarAgencia} className="hb-grid-3">
              <input className="hb-input" placeholder="Codigo" value={agencia.cod_agencia} onChange={(e) => setAgencia((s) => ({ ...s, cod_agencia: e.target.value }))} required />
              <input className="hb-input" placeholder="Nombre" value={agencia.nombre} onChange={(e) => setAgencia((s) => ({ ...s, nombre: e.target.value }))} required />
              <input className="hb-input" placeholder="Region" value={agencia.region} onChange={(e) => setAgencia((s) => ({ ...s, region: e.target.value }))} />
              <button className="hb-btn" disabled={saving}><PlusCircle size={16} /> Crear agencia</button>
            </form>
            <SimpleTable
              columns={['Codigo', 'Nombre', 'Region', 'Activa']}
              rows={agencias.map((a) => [a.cod_agencia, a.nombre, a.region || '-', a.activa ? 'Si' : 'No'])}
            />
          </Card>

          <Card title="Catalogos" icon={Tags} style={{ marginTop: 16 }}>
            <form onSubmit={guardarCatalogo} className="hb-grid-3">
              <input className="hb-input" placeholder="Tipo" value={catalogo.tipo} onChange={(e) => setCatalogo((s) => ({ ...s, tipo: e.target.value }))} required />
              <input className="hb-input" placeholder="Codigo" value={catalogo.codigo} onChange={(e) => setCatalogo((s) => ({ ...s, codigo: e.target.value }))} required />
              <input className="hb-input" placeholder="Nombre" value={catalogo.nombre} onChange={(e) => setCatalogo((s) => ({ ...s, nombre: e.target.value }))} required />
              <button className="hb-btn" disabled={saving}><PlusCircle size={16} /> Crear catalogo</button>
            </form>
            <SimpleTable
              columns={['Tipo', 'Codigo', 'Nombre', 'Activo']}
              rows={catalogos.map((c) => [c.tipo, c.codigo, c.nombre, c.activo ? 'Si' : 'No'])}
            />
          </Card>
        </>
      )}
    </>
  )
}

function SimpleTable({ columns, rows }) {
  if (!rows.length) return <div className="hb-table-empty" style={{ marginTop: 12 }}>Sin registros.</div>
  return (
    <div className="hb-table-wrap" style={{ marginTop: 16 }}>
      <table className="hb-table">
        <thead><tr>{columns.map((c) => <th key={c}>{c}</th>)}</tr></thead>
        <tbody>
          {rows.map((row, idx) => (
            <tr key={idx}>{row.map((cell, i) => <td key={i}>{cell}</td>)}</tr>
          ))}
        </tbody>
      </table>
    </div>
  )
}
