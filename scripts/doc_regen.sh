#!/usr/bin/env bash
set -euo pipefail

DOCS_DIR=${1:-docs/api}
SCRIPTS_ROOT=${2:-res://scripts/modules}
RST=${RST:-0}
HTML=${HTML:-0}

mkdir -p logs
echo "[doctool] Generating XML docs into ${DOCS_DIR}"
set +e
godot4 --headless --path . --doctool "${DOCS_DIR}" --gdscript-docs "${SCRIPTS_ROOT}" 2>&1 | tee logs/doctool.log
exit_code=${PIPESTATUS[0]}
set -e
if [ ${exit_code} -ne 0 ]; then
  echo "Doctool failed with exit code ${exit_code}. See logs/doctool.log"
  exit ${exit_code}
fi

if [ "${RST}" = "1" ]; then
  echo "[doctool] Converting XML -> RST"
  mkdir -p docs/api_rst
  PYTHONPATH="$(pwd)" python3 tools/make_rst.py -o docs/api_rst "${DOCS_DIR}" 2>&1 | tee logs/doctool_rst.log
fi

if [ "${HTML}" = "1" ]; then
  echo "[doctool] Converting RST -> HTML"
  mkdir -p docs/html
  python3 tools/rst_to_html.py docs/api_rst docs/html 2>&1 | tee logs/doctool_html.log
fi

echo "[doctool] Complete. Primary log: logs/doctool.log"
exit 0

