http://127.0.0.1:8000/api/chunks
# RAG Application (Static PDF + ChromaDB + Redis)

A RAG (Retrieval-Augmented Generation) app that answers questions about a single static PDF using ChromaDB for vectors and Redis for semantic Q&A caching.

## Quick start

- **First time (new machine / after unzip):** Double-click **`setup_and_run.cmd`** (see [BEFORE_START.txt](BEFORE_START.txt) for prerequisites).
- **Later runs:** Double-click **`start_all.cmd`**.

Then open **http://localhost:8501** for the UI and **http://127.0.0.1:8000** for the API (e.g. [http://127.0.0.1:8000/api/chunks](http://127.0.0.1:8000/api/chunks)).

## Documentation

Full documentation is in the **`docs/`** folder:

| Document | Description |
|----------|-------------|
| [docs/project_overview.md](docs/project_overview.md) | What the project is, goals, technologies, high-level architecture |
| [docs/architecture.md](docs/architecture.md) | Components, request flow, data stores, external services |
| [docs/folder_structure.md](docs/folder_structure.md) | Project tree and purpose of each folder |
| [docs/file_documentation.md](docs/file_documentation.md) | File-by-file description (purpose, callers, config) |
| [docs/execution_flow.md](docs/execution_flow.md) | Step-by-step startup and query flow |
| [docs/dependencies.md](docs/dependencies.md) | Environment variables, config, Python and external dependencies |
| [docs/setup_guide.md](docs/setup_guide.md) | Installation, running services, troubleshooting |
| [docs/maintenance_guide.md](docs/maintenance_guide.md) | Where to add features, change config, extend safely |
| [docs/APIM_INTEGRATION.md](docs/APIM_INTEGRATION.md) | Azure API Management (APIM) integration (optional, non-intrusive) |

## Requirements

- Python 3, pip, Docker (for Redis)
- `.env` with Azure OpenAI credentials (see [BEFORE_START.txt](BEFORE_START.txt))
- Static PDF at `docs/Essay on Narendra Modi.pdf` or path set in `STATIC_PDF_PATH`
