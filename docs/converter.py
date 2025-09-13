
import markdown
import sys
import os

# Add this block to handle potential import errors on different systems
try:
    from markdown.extensions.fenced_code import FencedCodeExtension
    from markdown.extensions.tables import TableExtension
except ImportError:
    # Fallback for environments where direct import might differ, though standard pip install should work
    FencedCodeExtension = 'fenced_code'
    TableExtension = 'tables'

if len(sys.argv) > 1:
    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"Error: File not found at {file_path}", file=sys.stderr)
        sys.exit(1)
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            text = f.read()
            # Use standard extensions for code blocks and tables
            html = markdown.markdown(text, extensions=[FencedCodeExtension(), TableExtension()])
            print(html)
    except Exception as e:
        print(f"Error processing file {file_path}: {e}", file=sys.stderr)
        sys.exit(1)
