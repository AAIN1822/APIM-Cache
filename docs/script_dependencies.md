# Script Dependencies and "What If I Remove These Files?"

## 1. How the Redis issue was diagnosed (not by running tests)

The Redis problem was **inferred from the information you provided**, not by executing the app or Docker locally:

1. **Your backend logs** said:
   - `Redis unavailable, caching disabled: Timeout connecting to server`
   - `Redis cache: disabled (connection failed or Redis not running)`
   - `Semantic cache NOT stored (Redis down?). Next question will use ChromaDB again.`  
   So the FastAPI process could not connect to Redis.

2. **Your Docker screenshot** showed:
   - **redis-rag**: running, but **Port(s) column empty** → no port published to the host.
   - **crudapp-redis**: stopped, but **Port(s) = 6379:6379** → that one was configured correctly.

3. **Docker behavior**: A container only exposes a port to the host if it was created with `-p host_port:container_port`. If `redis-rag` was created without `-p 6379:6379`, then `docker start redis-rag` does not add port mapping; the existing container keeps its (empty) port configuration.

4. **Conclusion**: The app connects to `localhost:6379`. Nothing was listening there because `redis-rag` had no port mapping → connection timeout → cache disabled. The fix was to remove the bad container and recreate it with `-p 6379:6379`, and to make the scripts do that automatically when the port is missing.

**How you can test/debug Redis yourself:**

- After starting services, check that port 6379 is published:
  ```powershell
  docker port redis-rag 6379
  ```
  Should print something like `0.0.0.0:6379` or `6379/tcp -> 0.0.0.0:6379`. If it errors or prints nothing, the container has no mapping.

- Check API startup logs for:
  - `Redis cache: OK (connected at startup)` → cache will be used.
  - `Redis unavailable, caching disabled` → cache disabled; fix Redis/port and restart API.

- Ask the same question twice in the UI: first time **Source: ChromaDB**, second time **Source: Redis Cache** means the cache is working.

---

## 2. What each file does and what depends on what

### Dependency diagram (code only; no script *executes* BEFORE_START.txt)

```
start_all.cmd
    └── calls: start_all.ps1   (only dependency)

setup_and_run.cmd  (if present)
    └── calls: setup_and_run.ps1

start_all.ps1      → no dependency on other scripts or on BEFORE_START.txt
setup_and_run.ps1  → no dependency on start_all or BEFORE_START.txt

BEFORE_START.txt   → not run by any script; documentation only
```

So:

- **start_all.cmd** depends **only on start_all.ps1** (it just launches that script).
- **setup_and_run.cmd** (if you have it) depends **only on setup_and_run.ps1**.
- **start_all.ps1** and **setup_and_run.ps1** do **not** depend on each other or on BEFORE_START.txt.
- **BEFORE_START.txt** is only referenced in **documentation** (e.g. README, BEFORE_START itself); no script reads or runs it.

### Role of each file

| File | Purpose | Depends on |
|------|--------|------------|
| **start_all.cmd** | Double‑click entry to start Redis + API + Streamlit (no setup). | **start_all.ps1** (must exist in same folder). |
| **start_all.ps1** | Starts Docker Redis, then uvicorn and Streamlit in new windows; uses .venv or D:\envv. | Nothing (standalone). |
| **setup_and_run.ps1** | Full setup (check Python/pip/Docker, create .venv, pip install, folders, Redis, then API + Streamlit). | Nothing (standalone). |
| **setup_and_run.cmd** | Double‑click entry to run full setup + start. | **setup_and_run.ps1** (if present). |
| **BEFORE_START.txt** | Prerequisites and notes (Docker, Python, .env, PDF, Redis port tip). | Nothing; no script uses it. |

---

## 3. What if you remove these files?

### If you remove **only BEFORE_START.txt**

- **Effect:** None on running the app. Scripts do not call or read it.
- **You lose:** The written checklist (Docker, Python, .env, PDF, Redis port). You’d still need to do those steps; you just wouldn’t have that file as a reference.

### If you remove **only start_all.ps1**

- **Effect:** **start_all.cmd** will **fail** when you double‑click it (it runs that .ps1 file).
- **Workaround:** Start everything manually: start Redis, then run uvicorn and streamlit from the project root (see run_app.txt or setup_guide).

### If you remove **only start_all.cmd**

- **Effect:** You can’t double‑click that .cmd anymore.
- **Workaround:** Run **start_all.ps1** directly from PowerShell:
  ```powershell
  cd D:\agent\azure-rag-app_final\azure-rag-app
  .\start_all.ps1
  ```

### If you remove **setup_and_run.ps1**

- **Effect:** **setup_and_run.cmd** (if present) will fail when you run it.
- **Workaround:** Do setup manually: create .venv, `pip install -r requirements.txt`, create folders, start Redis, then run API and Streamlit (see docs/setup_guide.md).

### If you remove **all four** (BEFORE_START.txt, start_all.cmd, start_all.ps1, setup_and_run.ps1)

- **Effect:**
  - No one‑click start or setup.
  - You must:
    - Install Python, pip, Docker, create venv, install deps, create folders, configure .env and PDF.
    - Start Redis: `docker run -d --name redis-rag -p 6379:6379 redis:7-alpine` (or `docker start redis-rag` if it already exists with port 6379).
    - Start API: `uvicorn app.main:app --reload --host 127.0.0.1 --port 8000` (from project root, with correct Python/venv).
    - Start UI: `streamlit run ui/streamlit_app.py`.
- **The application itself (app/, ui/, ChromaDB, Redis, Azure OpenAI) does not depend on these files.** They are only convenience scripts and documentation.

---

## 4. Summary

- **Redis was debugged** from your logs + Docker screenshot (timeout + empty port column), not by running tests in this environment.
- **start_all.cmd** is the only one of these that **depends on another file**: it needs **start_all.ps1**.
- **BEFORE_START.txt** and **setup_and_run.ps1** are not dependencies of any script; they’re docs and a standalone setup script.
- **Removing all four** only removes convenience; the app can still be set up and run manually as above.
