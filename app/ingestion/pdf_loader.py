from io import BytesIO
from pypdf import PdfReader


def load_pdf(file_bytes: bytes) -> str:
    """
    Load PDF text from raw bytes
    """
    pdf_stream = BytesIO(file_bytes)
    reader = PdfReader(pdf_stream)

    text = ""
    for page in reader.pages:
        page_text = page.extract_text()
        if page_text:
            text += page_text + "\n"

    return text
