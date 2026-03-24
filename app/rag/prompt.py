
# """
def build_prompt(context: str, question: str) -> str:
    return f"""
You are an information extraction assistant.

Use ONLY the context below to answer the question.
If the answer exists, list it explicitly.
If it does not exist, say "Not mentioned in the document".

Context:
{context}

Question:
{question}

Answer in clear bullet points if applicable.
"""
