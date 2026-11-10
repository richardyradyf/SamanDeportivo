#!/usr/bin/env bash
# Inspección y (solo bajo --aplicar explícito) reversión del merge PR #24.
# NO borra functions/: otros módulos todavía la necesitan en develop.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
MERGE="847b903c89c8d856d507d3145a4039e5853f9c2f"
modo="${1:---verificar}"
if [[ "$modo" != '--verificar' && "$modo" != '--aplicar' ]]; then
  echo 'Uso: bash scripts/revertir_trigger_pr24.sh [--verificar|--aplicar]' >&2
  exit 2
fi
branch="$(git branch --show-current)"
if [[ -z "$branch" || "$branch" == 'main' || "$branch" == 'develop' ]]; then
  echo "ERROR: no ejecutar sobre main/develop ni HEAD detached (rama=$branch)" >&2
  exit 3
fi
if ! git cat-file -e "$MERGE^{commit}" 2>/dev/null; then
  echo 'ERROR: falta el merge PR #24 en el historial local. Ejecuta git fetch origin.' >&2
  exit 4
fi
if ! git merge-base --is-ancestor "$MERGE" HEAD; then
  echo 'ERROR: PR #24 no es ancestro de la rama actual; no revertir a ciegas.' >&2
  exit 5
fi
parentes="$(git show --format='%P' --no-patch "$MERGE")"
if [[ $(wc -w <<< "$parentes" | tr -d ' ') -ne 2 ]]; then
  echo 'ERROR: el commit especificado no es un merge de dos padres.' >&2
  exit 6
fi
expected=$'functions/index.cjs\nfunctions/lib/indicadores_resenas.cjs\nfunctions/test/indicadores_resenas.test.cjs\ntest/functions/a3_7_trigger_emulator.test.mjs'
actual="$(git diff --name-only "$MERGE^1" "$MERGE" | sort)"
if [[ "$actual" != "$(printf '%s\n' "$expected" | sort)" ]]; then
  echo 'ERROR: el merge PR #24 modifica archivos inesperados; revisión manual.' >&2
  printf 'Archivos encontrados:\n%s\n' "$actual" >&2
  exit 7
fi
if ! grep -q 'transaccion.update(deporte' lib/features/estudiante/catalogo/data/firestore_resena_repository.dart; then
  echo 'ERROR: falta el cálculo transaccional en Flutter; no apagar trigger.' >&2
  exit 8
fi
if ! grep -q 'exports.recalcularCalificacionesDeporte' functions/index.cjs; then
  echo 'El trigger no aparece en functions/index.cjs. Comprueba si ya fue revertido.' >&2
  exit 9
fi

echo "OK: rama '$branch' contiene PR #24, y el cálculo transaccional existe."
echo 'PR #24 únicamente agregó el trigger y tres archivos de pruebas/implementación.'
if [[ "$modo" == '--verificar' ]]; then
  echo 'MODO PREVISUALIZACIÓN: no se cambió nada.'
  echo 'Después del commit de Spark y con git diff limpio, ejecutar --aplicar.'
  exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo 'ERROR: hay cambios rastreados sin commitear. Revert requiere árbol limpio.' >&2
  exit 10
fi
# Mantener el revert como commit separado dentro del MISMO PR de Spark.
# -m 1 selecciona la línea principal (develop) del merge, no la rama feature.
echo "Revirtiendo el PR #24 (merge $MERGE) en la rama '$branch'..."
git -c core.editor=true revert --no-edit -m 1 "$MERGE"
echo 'OK: commit de reversión creado localmente. No se hizo push ni deploy.'
echo 'Revisar: git show --stat HEAD; grep -R recalcularCalificacionesDeporte functions/ || true'
