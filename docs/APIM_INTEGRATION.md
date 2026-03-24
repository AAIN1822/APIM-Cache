# Azure API Management (APIM) – Full Integration Guide

This guide explains what Azure resources to create, how the integration is architected, what code/config changes exist in this project, and how to test that APIM is working while keeping existing behaviour unchanged.

---

# Step-by-step implementation plan

1. **Azure:** Create APIM instance → Create Backend (your FastAPI base URL) → Create API with suffix (e.g. `rag`) and link Backend → Add operations (POST `/api/query`, GET `/api/chunks`, GET `/health`) → Add/use a Product and create a Subscription → Copy subscription key.
2. **Backend:** Deploy or expose your FastAPI app at a URL reachable by APIM. If the app runs behind APIM, set `BEHIND_APIM=true` in its environment.
3. **Optional – UI:** To call through APIM from Streamlit, set `BACKEND_URL` to the APIM gateway URL and `OCP_APIM_SUBSCRIPTION_KEY` to the key.
4. **Test:** Verify direct backend (4.1) → then call via APIM URL (4.2) → validate traffic in APIM (4.3) → test subscription key (4.4) → confirm existing behaviour unchanged (4.5).

No backend code change is required for existing endpoints; only configuration and optional env for the UI.

---

# 1. Required Azure Resources

Create and configure the following in your Azure subscription.

## 1.1 API Management instance

- **Resource:** API Management service (e.g. **Developer** or **Consumption** tier for testing).
- **Where:** Azure Portal → Create a resource → API Management.
- **Settings:** Name, subscription, resource group, region, pricing tier. Note the **Gateway URL** (e.g. `https://<your-apim-name>.azure-api.net`).

## 1.2 Backend (this FastAPI app)

- **Resource:** A **Backend** in APIM that points at your running RAG API.
- **Purpose:** Tells APIM where to forward requests (your FastAPI base URL).
- **Configuration:**
  - **URL:** Base URL of the app, e.g.:
    - Local/dev: `http://<your-machine-ip>:8000` or a tunnel URL (ngrok, etc.).
    - Azure: `https://<your-app-service>.azurewebsites.net` or the URL of the container/VM hosting the API.
  - **Protocol:** HTTP or HTTPS as appropriate.
  - Optional: **Health check URL** = `@(context.Backend.BaseUrl)/health` (or set in backend health probe to `/health`).

## 1.3 API (in APIM)

- **Resource:** One **API** in APIM representing the RAG API.
- **Settings:**
  - **Name:** e.g. `rag-api`.
  - **Web service URL:** Leave empty if you use a single backend and path forwarding; or set to the backend base URL.
  - **API URL suffix:** e.g. `rag` so the gateway path is `https://<apim>.azure-api.net/rag`.
  - **Backend:** Select the backend created above.

## 1.4 Operations

Define operations that map to your existing endpoints (no backend code change):

| APIM operation   | Method | URL template (relative to backend) | Backend path   |
|------------------|--------|-----------------------------------|----------------|
| Query            | POST   | `/api/query`                      | `POST /api/query` |
| List chunks      | GET    | `/api/chunks`                     | `GET /api/chunks` |
| Health           | GET    | `/health`                         | `GET /health`  |

- **Forwarding:** Set “Backend” to your RAG backend; APIM will forward the same path and body/query. No rewrite needed if the backend is the root (e.g. `http://backend:8000` and path `/api/query`).

## 1.5 Product

- **Resource:** A **Product** (e.g. **Unlimited** or a custom product).
- **Purpose:** Groups the API and defines visibility (e.g. published so developers can subscribe).
- **Configuration:** Add the `rag-api` API to the product; set subscription required if you want subscription keys.

## 1.6 Subscription (for subscription key)

- **Resource:** A **Subscription** under the product.
- **Purpose:** Provides a **primary (and optional secondary) subscription key** for calling the API through APIM.
- **Where:** APIM → Subscriptions → Add subscription; select the product and optionally an API. Copy the **Primary key** (and optionally Secondary) for use in clients.

---

# 2. Integration Architecture

## 2.1 Flow without APIM (unchanged)

```
Client (browser / Streamlit / curl)
    → http://127.0.0.1:8000/api/query (or /api/chunks, /health)
    → FastAPI app (this project)
    → Response
```

## 2.2 Flow with APIM

```
Client
    → https://<apim-name>.azure-api.net/rag/api/query
    → (Optional: Ocp-Apim-Subscription-Key header)
    → Azure API Management
        → Validates subscription key (if required)
        → Applies policies (rate limit, etc.)
        → Forwards to Backend: http://<your-backend>:8000/api/query
    → FastAPI app (this project)
    → Response back through APIM to client
```

## 2.3 Diagram

```
┌─────────────┐     ┌──────────────────────────────────────────┐     ┌─────────────────┐
│   Client    │────▶│  Azure API Management                     │────▶│  This project   │
│ (UI / curl) │     │  - Gateway: *.azure-api.net/rag            │     │  (FastAPI)      │
└─────────────┘     │  - Subscription key (optional)            │     │  - /health      │
                    │  - Backend: your FastAPI base URL          │     │  - /api/query   │
                    │  - Operations: query, chunks, health       │     │  - /api/chunks  │
                    └──────────────────────────────────────────┘     └─────────────────┘
```

## 2.4 Path mapping

- If your APIM **API URL suffix** is `rag`, then:
  - Client calls: `https://<apim>.azure-api.net/rag/api/query`
  - APIM forwards to backend: `http://<backend>:8000/api/query` (path can be forwarded as-is if backend base URL has no path suffix).
- Backend **endpoints stay the same**; only the host (and optionally a path prefix) and subscription key change for the client.

---

# 3. Code/Config Changes in This Project

Existing API behaviour is unchanged. Only the following are added or optional.

## 3.1 Files modified or added

| File | Change |
|------|--------|
| **app/config.py** | Added optional `BEHIND_APIM` (env). When `true`, enables trusting `X-Forwarded-For` from the gateway. Default `false` → no impact when not behind APIM. |
| **app/main.py** | Added `GET /health` for APIM backend health checks; added optional `ProxyHeadersMiddleware` when `BEHIND_APIM=true`. No change to `POST /api/query` or `GET /api/chunks`. |
| **ui/streamlit_app.py** | Backend URL and subscription key now configurable via env: `BACKEND_URL`, `OCP_APIM_SUBSCRIPTION_KEY`. Defaults keep current behaviour (direct backend, no key). |
| **docs/APIM_INTEGRATION.md** | This guide. |

No changes to: `app/api/query.py`, RAG chain, cache, ChromaDB, ingestion, or any other business logic.

## 3.2 Environment variables

| Variable | Used in | Purpose | Default |
|----------|--------|---------|---------|
| **BEHIND_APIM** | Backend (config) | When `true`/`1`/`yes`, trust `X-Forwarded-For` so the app sees the real client IP. Set when the app is behind APIM (or any reverse proxy). | `false` |
| **BACKEND_URL** | Streamlit UI | Base URL the UI uses for API calls. Set to APIM gateway URL (e.g. `https://<apim>.azure-api.net/rag`) to route through APIM. | `http://127.0.0.1:8000` |
| **OCP_APIM_SUBSCRIPTION_KEY** | Streamlit UI | If APIM requires a subscription key, set this so the UI sends `Ocp-Apim-Subscription-Key` on requests. | (empty) |

Backend **.env** (when running behind APIM):

```env
BEHIND_APIM=true
```

Streamlit **.env** or environment (when testing UI through APIM):

```env
BACKEND_URL=https://<your-apim-name>.azure-api.net/rag
OCP_APIM_SUBSCRIPTION_KEY=<your-primary-key>
```

## 3.3 Authentication / gateway configuration

- **Subscription key:** Handled entirely in APIM (product/subscription). Backend does not validate the key; APIM strips or validates it before forwarding. Clients send header: `Ocp-Apim-Subscription-Key: <key>`.
- **Backend auth:** This project does not require APIM to send any special auth to the backend; if you add backend auth later, you can configure it in APIM policies (e.g. set a header from a key vault).
- **CORS:** If clients are browser-based and call APIM from another origin, configure CORS in APIM (e.g. `cors` policy) or on the backend; current backend has no CORS middleware, so for cross-origin UI either enable CORS on the backend or use APIM CORS.

## 3.4 Do existing API endpoints need modification?

**No.**  
- `POST /api/query` and `GET /api/chunks` are unchanged in contract and behaviour.  
- They are called the same way; only the base URL (and optionally subscription key) change when going through APIM.  
- `GET /health` was added only for health checks; existing clients are unaffected.

---

# 4. Step-by-Step Testing Process

## 4.1 Verify existing APIs still work (without APIM)

1. Start the app as usual (e.g. `runproject.cmd` or manual Redis + uvicorn + Streamlit).
2. **Health:**
   ```bash
   curl -s http://127.0.0.1:8000/health
   ```
   Expected: `{"status":"ok"}` and HTTP 200.
3. **Query:**
   ```bash
   curl -s -X POST http://127.0.0.1:8000/api/query -H "Content-Type: application/json" -d "{\"question\": \"Where was he born?\"}"
   ```
   Expected: JSON with `answer` and `source`.
4. **Chunks:**
   ```bash
   curl -s "http://127.0.0.1:8000/api/chunks"
   ```
   Expected: JSON with `document_id`, `count`, `chunks`.
5. **Streamlit:** Open UI, ask a question. Expected: same behaviour as before.

This confirms current functionality is unchanged.

---

## 4.2 Call APIs through the APIM gateway URL

Assume APIM gateway base URL is `https://<your-apim>.azure-api.net` and API suffix is `rag`. Replace with your values.

1. **Health via APIM:**
   ```bash
   curl -s "https://<your-apim>.azure-api.net/rag/health"
   ```
   If subscription is required, add the key:
   ```bash
   curl -s -H "Ocp-Apim-Subscription-Key: <your-primary-key>" "https://<your-apim>.azure-api.net/rag/health"
   ```
   Expected: `{"status":"ok"}` and 200.

2. **Query via APIM:**
   ```bash
   curl -s -X POST "https://<your-apim>.azure-api.net/rag/api/query" \
     -H "Content-Type: application/json" \
     -H "Ocp-Apim-Subscription-Key: <your-primary-key>" \
     -d "{\"question\": \"Where was he born?\"}"
   ```
   Expected: same JSON shape as when calling the backend directly (`answer`, `source`).

3. **Chunks via APIM:**
   ```bash
   curl -s -H "Ocp-Apim-Subscription-Key: <your-primary-key>" "https://<your-apim>.azure-api.net/rag/api/chunks"
   ```
   Expected: same as direct backend.

4. **Streamlit through APIM:**  
   Set env and run Streamlit:
   ```bash
   set BACKEND_URL=https://<your-apim>.azure-api.net/rag
   set OCP_APIM_SUBSCRIPTION_KEY=<your-primary-key>
   streamlit run ui/streamlit_app.py
   ```
   Ask a question in the UI; it should go through APIM and behave the same as when using the backend URL.

---

## 4.3 Validate that requests are passing through APIM

1. **Response headers:**  
   Call an endpoint through APIM with `-v` and inspect response headers; you often see APIM-related headers (e.g. `X-Request-Id`, `apim-request-id` or similar, depending on APIM version). Direct calls to the backend do not include these.

2. **APIM Analytics / Logs:**  
   In Azure Portal → your APIM → Analytics or Logs, run a query for requests to your API. You should see requests for `/rag/health`, `/rag/api/query`, `/rag/api/chunks` when calling via the gateway.

3. **Backend logs:**  
   When you call via APIM, the backend still receives the request (from APIM’s IP). With `BEHIND_APIM=true`, your app can log the client IP from `X-Forwarded-For`; that will show the original caller if APIM forwards the header.

4. **Temporarily break the backend URL in APIM:**  
   Change the backend URL to an invalid host; calls through APIM should then fail (e.g. 502), while direct calls to the correct backend URL still work. Restore the backend URL afterward.

---

## 4.4 Test subscription keys / authentication

1. **Subscription required:**  
   In APIM, set the product/API to require subscription. Call **without** `Ocp-Apim-Subscription-Key`: expect 401 Unauthorized. Call **with** a valid key: expect 200 and normal body.

2. **Wrong key:**  
   Send an invalid or expired key: expect 401.

3. **Primary vs secondary key:**  
   If you have both, call with each; both should work (unless you revoked one).

4. **Streamlit:**  
   With `OCP_APIM_SUBSCRIPTION_KEY` set to a valid key, the UI should get 200 and display answers when using `BACKEND_URL` as the APIM base. With key missing or wrong, you get 401 from APIM.

---

## 4.5 Confirm existing APIs still work as before

- **Direct backend:** With APIM in place, continue calling `http://<backend>:8000/health`, `/api/query`, `/api/chunks` as in 4.1. Behaviour and response bodies must remain the same.
- **No breaking changes:** No new required headers or query parameters for the backend; no change to request/response JSON for `query` and `chunks`.
- **Streamlit default:** With no `BACKEND_URL` or `OCP_APIM_SUBSCRIPTION_KEY` set, the UI still uses `http://127.0.0.1:8000` and no subscription key, so local workflow is unchanged.

---

# Summary

| Topic | Summary |
|-------|---------|
| **Azure resources** | APIM instance, Backend (your FastAPI URL), API + operations (query, chunks, health), Product, Subscription (for keys). |
| **Architecture** | Clients → APIM (optional key + policies) → your FastAPI backend; same paths and behaviour. |
| **Code/config** | Backend: `BEHIND_APIM`, `GET /health`, optional proxy middleware. UI: `BACKEND_URL`, `OCP_APIM_SUBSCRIPTION_KEY`. No change to existing endpoint logic. |
| **Testing** | (1) Direct backend unchanged; (2) Call same operations via APIM URL (+ key if required); (3) Use headers/analytics to confirm traffic via APIM; (4) Test with/without/wrong subscription key; (5) Confirm direct and default UI behaviour unchanged. |

Existing functionality and workflow remain unaffected; APIM is an optional gateway in front of the same API.
