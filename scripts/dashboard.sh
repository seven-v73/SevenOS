#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"

printf 'SevenOS Dashboard\n'
printf '=================\n\n'

printf 'System\n'
"$ROOT_DIR/install.sh" status 2>/dev/null | sed -n '1,36p' || true

printf '\nProfiles\n'
"$ROOT_DIR/bin/sevenpkg" status 2>/dev/null || true

printf '\nReadiness\n'
"$ROOT_DIR/scripts/readiness.sh" 2>/dev/null | sed -n '/== Summary ==/,$p' || true

printf '\nCyber\n'
"$ROOT_DIR/install.sh" cyber-audit 2>/dev/null | sed -n '1,24p' || true

printf '\nQuick Actions\n'
printf '  seven hub\n'
printf '  seven readiness\n'
printf '  seven improve\n'
printf '  seven profile status\n'
printf '  seven shield audit\n'
printf '  sevenpkg install forge\n'
