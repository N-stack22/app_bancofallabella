# Activacion Supabase Cloud

## Backend core-api

El backend ya esta preparado para leer Supabase Cloud desde variables de entorno.
En Railway, Render o un hosting equivalente configura:

```env
DATABASE_URL=postgresql+psycopg2://postgres.PROJECT_REF:PASSWORD@aws-0-us-east-1.pooler.supabase.com:6543/postgres
CORE_DATABASE_URL=postgresql+psycopg2://postgres.PROJECT_REF:PASSWORD@aws-0-us-east-1.pooler.supabase.com:6543/postgres
SECRET_KEY=una_clave_larga_segura
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=480
SUPABASE_URL=https://oqkuvygkchsftzclakyu.supabase.co
SUPABASE_SERVICE_ROLE_KEY=solo_en_backend
SUPABASE_BUCKET_DOCUMENTOS=documentos-credito
```

El comando de arranque para produccion es:

```bash
uvicorn main:app --host 0.0.0.0 --port $PORT
```

## Web en Firebase Hosting

Cuando el backend tenga URL publica HTTPS, compila la web con:

```bash
cd web-core
$env:VITE_API_URL="https://n-stack22-bancofallabela-production.up.railway.app"
npm run build
cd ..
firebase deploy --only hosting
```

La ruta publicada sera:

```text
https://falanellaweb.web.app/inicio
```

## Apps moviles Flutter

App clientes y fuerza de ventas deben apuntar al backend publico:

```bash
flutter run --dart-define=CORE_BASE_URL=https://n-stack22-bancofallabela-production.up.railway.app
```

La app fuerza de ventas tambien usa Supabase Cloud directo. Compilala con la anon public key, no con service_role:

```bash
flutter run \
  --dart-define=CORE_BASE_URL=https://n-stack22-bancofallabela-production.up.railway.app \
  --dart-define=SUPABASE_URL=https://oqkuvygkchsftzclakyu.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_PUBLIC_KEY \
  --dart-define=SUPABASE_BUCKET_DOCUMENTOS=documentos-credito
```

La `SUPABASE_SERVICE_ROLE_KEY` nunca debe ir en Flutter ni en Firebase Hosting.
