import requests
import streamlit as st

API_URL = "https://uniview-apim-new.azure-api.net/rag"
HEADERS = {
    "Ocp-Apim-Subscription-Key": "b4f18b4b697044f2b311e3ccd6890a96",
    "Content-Type": "application/json"
}

st.set_page_config(page_title="PDF RAG Chat", layout="centered")
st.title("Ask questions (static PDF)")
st.caption("Essay on Narendra Modi.pdf — indexed at API startup")

question = st.text_input("Type your question")

if st.button("Ask"):
    if not question.strip():
        st.warning("Please enter a question")
    else:
        with st.spinner("Thinking..."):
            res = requests.post(
                API_URL + "/api/query",
                json={"question": question.strip()},
                headers=HEADERS
            )

        if res.status_code == 200:
            data = res.json()
            st.markdown("### Answer")
            st.write(data["answer"])
            if data.get("source"):
                color = "green" if "Redis" in data["source"] else "blue"
                st.caption(f"Source: :{color}[**{data['source']}**]")
        else:
            st.error(f"Error {res.status_code}: {res.text}")