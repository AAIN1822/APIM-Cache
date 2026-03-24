"""
Questions only — PDF is loaded from disk at API startup (docs/Essay on Narendra Modi.pdf).
Optional: set BACKEND_URL / OCP_APIM_SUBSCRIPTION_KEY in env to call via Azure APIM.
"""

import os
import requests
import streamlit as st

# Default: direct backend; set BACKEND_URL to APIM gateway URL to route through APIM
BACKEND_URL = os.getenv("BACKEND_URL", "http://127.0.0.1:8000")
# When using APIM with subscription key, set this so the UI sends the key (optional)
APIM_SUBSCRIPTION_KEY = os.getenv("OCP_APIM_SUBSCRIPTION_KEY", "")

st.title("")
st.info(
    " Question"
    "."
)

question = st.text_input("Ask a question", key="question_input")

if st.button("Ask"):
    if not question.strip():
        st.warning("Please enter a question")
    else:
        with st.spinner("Retrieving answer…"):
            try:
                headers = {"Content-Type": "application/json"}
                if APIM_SUBSCRIPTION_KEY:
                    headers["Ocp-Apim-Subscription-Key"] = APIM_SUBSCRIPTION_KEY
                res = requests.post(
                    f"{BACKEND_URL}/api/query",
                    json={"question": question.strip()},
                    headers=headers,
                )
                if res.status_code == 200:
                    data = res.json()
                    st.markdown("### Answer")
                    st.write(data["answer"])
                    if data.get("source"):
                        st.caption(f"Source: **{data['source']}**")
                else:
                    st.error(f"Failed ({res.status_code}): {res.text[:500]}")
            except Exception as e:
                st.error(str(e))
