from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from app.core.cfg_config import settings


def _connect_args(database_url: str) -> dict:
    if "supabase.com" in database_url and "sslmode=" not in database_url:
        return {"sslmode": "require"}
    return {}


engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
    pool_size=5,
    max_overflow=10,
    connect_args=_connect_args(settings.DATABASE_URL),
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# --- Conexion secundaria al nucleo bancario (bd_core_financiero) ---
# Usada solo por el servicio de promocion (sync_outbox -> core).
core_engine = create_engine(
    settings.CORE_DATABASE_URL,
    pool_pre_ping=True,
    pool_size=2,
    max_overflow=4,
    connect_args=_connect_args(settings.CORE_DATABASE_URL),
)

SessionLocalCore = sessionmaker(autocommit=False, autoflush=False, bind=core_engine)
