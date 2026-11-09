#!/usr/bin/env bash
# Ejecutar desde la raiz del worktree de Samán Deportivo.
# No despliega reglas, no realiza commit y nunca usa el proyecto real.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

if [[ ! -f pubspec.yaml || ! -f firebase.security.test.json ]]; then
  echo 'ERROR: carpeta incorrecta; ejecuta desde el repositorio de Samán.' >&2
  exit 2
fi

python3 scripts/verificar_spark_alexander.py
node --check test/firestore/firestore.rules.test.mjs
node --check test/firestore/spark_concurrencia.rules.test.mjs

if [[ ! -d node_modules ]]; then
  echo 'Instalando dependencias npm desde package-lock.json ...'
  npm ci
fi

echo '== Suite principal (127 pruebas de referencia) =='
npm run test:rules

echo '== Suite de concurrencia de dos administradores (5 pruebas nuevas) =='
# El ID demo impide que los SDK de pruebas contacten la base real.
firebase emulators:exec --config firebase.security.test.json \
  --project demo-saman-concurrencia --only firestore \
  'node --test test/firestore/spark_concurrencia.rules.test.mjs'

echo '== Análisis y pruebas Flutter =='
flutter analyze
flutter test

echo '== Validación Git =='
git diff --check
git diff --cached --check

echo 'QA completado: verificar que todas las suites hayan terminado con código 0.'
echo 'Atención: la suite JS prueba reglas y concurrencia del control, NO reemplaza'
echo 'las pruebas con dos navegadores usando el gateway Flutter.'
