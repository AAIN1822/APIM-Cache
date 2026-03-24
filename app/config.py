import os
from dotenv import load_dotenv

# Load .env once, globally (from project root)
load_dotenv()

# -------------------------
# Azure OpenAI (required)
# -------------------------
AZURE_OPENAI_ENDPOINT = os.getenv("AZURE_OPENAI_ENDPOINT")
AZURE_OPENAI_KEY = os.getenv("AZURE_OPENAI_KEY")
AZURE_OPENAI_CHAT_DEPLOYMENT = os.getenv("AZURE_OPENAI_CHAT_DEPLOYMENT")
AZURE_OPENAI_EMBED_DEPLOYMENT = os.getenv("AZURE_OPENAI_EMBED_DEPLOYMENT")

# -------------------------
# Blob Storage (legacy / optional)
# -------------------------
BLOB_CONNECTION_STRING = os.getenv("BLOB_CONNECTION_STRING")
BLOB_CONTAINER = os.getenv("BLOB_CONTAINER")

# -------------------------
# ChromaDB (vector store)
# -------------------------
CHROMA_DB_DIR = os.getenv("CHROMA_DB_DIR", "./chroma_db")
CHROMA_COLLECTION_NAME = os.getenv("CHROMA_COLLECTION_NAME", "documents")

# -------------------------
# Static PDF (indexed at startup)
# -------------------------
STATIC_DOCUMENT_ID = os.getenv(
    "STATIC_DOCUMENT_ID",
    "00000000-0000-4000-8000-000000000001",
)
STATIC_PDF_PATH = os.getenv(
    "STATIC_PDF_PATH",
    "docs/Essay on Narendra Modi.pdf",
)

# -------------------------
# Redis (semantic cache for Q&A; optional)
# -------------------------
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379/0")
CACHE_TTL_SECONDS = int(os.getenv("CACHE_TTL_SECONDS", "120"))
CACHE_SIMILARITY_THRESHOLD = float(os.getenv("CACHE_SIMILARITY_THRESHOLD", "0.90"))

# -------------------------
# Azure API Management / reverse proxy (optional)
# -------------------------
BEHIND_APIM = os.getenv("BEHIND_APIM", "").strip().lower() in ("1", "true", "yes")

print("Config loaded")
print("Azure OpenAI Endpoint:", AZURE_OPENAI_ENDPOINT)
print("Azure OpenAI Chat Deployment:", AZURE_OPENAI_CHAT_DEPLOYMENT)
print("Azure OpenAI Embed Deployment:", AZURE_OPENAI_EMBED_DEPLOYMENT)
print("ChromaDB path:", CHROMA_DB_DIR)
print("Static PDF:", STATIC_PDF_PATH)
print("Static document_id:", STATIC_DOCUMENT_ID)
print("Redis URL:", REDIS_URL)
print("Cache TTL (seconds):", CACHE_TTL_SECONDS)
print("Cache similarity threshold:", CACHE_SIMILARITY_THRESHOLD)
print("Behind APIM (proxy headers):", BEHIND_APIM)