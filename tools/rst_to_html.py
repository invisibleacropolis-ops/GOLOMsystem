#!/usr/bin/env python3
"""Convert a directory of reStructuredText files to HTML.

This utility is a thin wrapper around docutils' ``publish_file`` that
processes every ``.rst`` file in the provided source directory and
writes an HTML file with the same base name to the destination
directory.
"""
import os
import sys
from docutils.core import publish_file

if len(sys.argv) != 3:
    print("Usage: rst_to_html.py <rst_dir> <html_dir>")
    sys.exit(1)

rst_dir, html_dir = sys.argv[1:3]
os.makedirs(html_dir, exist_ok=True)

for name in os.listdir(rst_dir):
    if not name.endswith(".rst"):
        continue
    src = os.path.join(rst_dir, name)
    dst = os.path.join(html_dir, name[:-4] + ".html")
    publish_file(source_path=src, destination_path=dst, writer_name="html5")
