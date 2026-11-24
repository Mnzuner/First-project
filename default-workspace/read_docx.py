from docx import Document

path = r"C:\Users\lin19\Desktop\第六组.docx"
doc = Document(path)

out = []
out.append("=== PARAGRAPHS ===")
for i, p in enumerate(doc.paragraphs):
    t = p.text.rstrip()
    if t.strip():
        out.append(f"[{i}] ({p.style.name}) {t}")

out.append("\n=== TABLES ===")
for ti, tb in enumerate(doc.tables):
    out.append(f"--- table {ti} ---")
    for row in tb.rows:
        out.append(" | ".join(c.text.strip() for c in row.cells))

out.append("\n=== HEADERS/FOOTERS ===")
for s in doc.sections:
    for name in ("header", "footer"):
        part = getattr(s, name)
        txt = "\n".join(p.text for p in part.paragraphs if p.text.strip())
        if txt.strip():
            out.append(f"{name}: {txt}")

with open(r"C:\Users\lin19\Documents\deepseek-harness\default-workspace\docx_dump.txt", "w", encoding="utf-8") as f:
    f.write("\n".join(out))
print("ok", len(out))
