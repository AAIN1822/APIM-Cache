import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI
from starlette.middleware.base import BaseHTTPMiddleware

import app.config as config
from app.api.query import router as query_router
from app.bootstrap_static_pdf import load_static_pdf_into_chroma


def _check_redis_at_startup():
    print("Python executable:", sys.executable)
    try:
        from app.cache import _get_redis

        client = _get_redis()
        if client:
            print("Redis cache: OK (connected at startup)")
        else:
            print("Redis cache: disabled (connection failed or Redis not running)")
    except Exception as e:
        print("Redis cache: disabled (%s)" % e)


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("FastAPI started")
    _check_redis_at_startup()
    try:
        load_static_pdf_into_chroma()
        print("Static PDF loaded into ChromaDB OK")
    except Exception as e:
        print("Static PDF load FAILED:", e)
    yield


# -----------------------------------------------------------------------------
# Optional: when running behind Azure API Management (or any reverse proxy),
# trust X-Forwarded-For so request.client reflects the real caller. Only
# applied when BEHIND_APIM=true; existing behaviour unchanged otherwise.
# -----------------------------------------------------------------------------
class ProxyHeadersMiddleware(BaseHTTPMiddleware):
    """Set request.client from X-Forwarded-For when behind APIM/proxy."""

    async def dispatch(self, request, call_next):
        if config.BEHIND_APIM:
            forwarded = request.headers.get("x-forwarded-for")
            if forwarded:
                # First address is the client (APIM appends others)
                client_host = forwarded.split(",")[0].strip()
                request.scope["client"] = (client_host, request.scope.get("client", ("", 0))[1])
        return await call_next(request)


app = FastAPI(title="RAG (static PDF + ChromaDB + Redis)", lifespan=lifespan)

# Apply proxy-headers middleware only when explicitly enabled (non-intrusive)
if config.BEHIND_APIM:
    app.add_middleware(ProxyHeadersMiddleware)

# Health endpoint for APIM backend health check; no dependency on RAG/Redis
@app.get("/health")
async def health():
    """Return 200 when the service is up. Used by APIM for backend health checks."""
    return {"status": "ok"}

app.include_router(query_router, prefix="/api")
