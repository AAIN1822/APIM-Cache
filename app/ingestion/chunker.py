from langchain_text_splitters import RecursiveCharacterTextSplitter

def chunk_text(text: str, size: int = 800, overlap: int = 150):
    splitter = RecursiveCharacterTextSplitter(
        chunk_size=size,
        chunk_overlap=overlap,
        separators=["\n\n", "\n", " ", ""]
    )

    chunks = splitter.split_text(text)
    print(f"✂️ Created {len(chunks)} chunks")
    return chunks
