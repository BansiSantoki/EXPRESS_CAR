from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
md_path = ROOT / "EXPRESS_CAR_VIVA_REPORT_GUJ.md"
html_path = ROOT / "EXPRESS_CAR_VIVA_REPORT_GUJ.html"
pdf_path = ROOT / "EXPRESS_CAR_VIVA_REPORT_GUJ.pdf"

md_text = md_path.read_text(encoding="utf-8")
escaped = (
    md_text.replace("&", "&amp;")
    .replace("<", "&lt;")
    .replace(">", "&gt;")
)

html_doc = f"""<!doctype html>
<html lang=\"gu\">
<head>
  <meta charset=\"utf-8\" />
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\" />
  <title>Express Car Viva Report</title>
  <style>
    body {{
      font-family: \"Nirmala UI\", \"Shruti\", \"Segoe UI\", sans-serif;
      background: #f4f6f8;
      margin: 0;
      padding: 0;
    }}
    .page {{
      max-width: 920px;
      margin: 24px auto;
      background: #ffffff;
      padding: 36px;
      box-shadow: 0 2px 12px rgba(0, 0, 0, 0.08);
    }}
    pre {{
      white-space: pre-wrap;
      word-wrap: break-word;
      font-size: 13px;
      line-height: 1.55;
      margin: 0;
    }}
    @media print {{
      body {{ background: #ffffff; }}
      .page {{ box-shadow: none; margin: 0; max-width: none; }}
    }}
  </style>
</head>
<body>
  <div class=\"page\">
    <pre>{escaped}</pre>
  </div>
</body>
</html>
"""

html_path.write_text(html_doc, encoding="utf-8")

browser_candidates = [
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"),
]

browser = next((p for p in browser_candidates if p.exists()), None)
if browser is None:
    print("No supported browser executable found for headless PDF export.")
    sys.exit(1)

file_url = html_path.resolve().as_uri()

cmd = [
    str(browser),
    "--headless=new",
    f"--print-to-pdf={pdf_path}",
    "--disable-gpu",
    "--no-first-run",
    "--no-default-browser-check",
    file_url,
]

result = subprocess.run(cmd, capture_output=True, text=True)
if result.returncode != 0:
    print(result.stdout)
    print(result.stderr)
    sys.exit(result.returncode)

print(f"PDF generated at: {pdf_path}")
