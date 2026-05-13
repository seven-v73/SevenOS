#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

usage() {
  cat <<'EOF'
SevenOS Deploy

Usage:
  seven deploy [project]
  seven deploy <action> [project]
  ./server/seven-deploy.sh <action> [project]

Actions:
  plan       Detect stack and write a non-destructive deployment plan
  detect     Print detected project stack
  status     Show generated deployment plans
  logs       Show known deployment log paths

Examples:
  seven deploy ./my-project
  seven deploy plan ./my-project
  seven deploy detect ./my-project
EOF
}

project_name() {
  basename "$(cd -- "$1" && pwd)"
}

detect_stack() {
  local project_dir="$1"
  local detected=()

  [[ -f "$project_dir/package.json" ]] && detected+=("node")
  [[ -f "$project_dir/go.mod" ]] && detected+=("go")
  [[ -f "$project_dir/composer.json" && -f "$project_dir/artisan" ]] && detected+=("laravel")
  [[ -f "$project_dir/pubspec.yaml" ]] && detected+=("flutter")
  [[ -f "$project_dir/Dockerfile" || -f "$project_dir/Containerfile" || -f "$project_dir/docker-compose.yml" || -f "$project_dir/compose.yaml" ]] && detected+=("container")

  if [[ "${#detected[@]}" -eq 0 ]]; then
    printf 'static'
  else
    printf '%s\n' "${detected[@]}" | paste -sd ',' -
  fi
}

plan_steps() {
  local stack="$1"

  IFS=',' read -ra stacks <<<"$stack"
  for item in "${stacks[@]}"; do
    case "$item" in
      node)
        printf 'npm install\n'
        printf 'npm run build --if-present\n'
        printf 'podman run rootless Node runtime or Caddy static handoff\n'
        ;;
      go)
        printf 'go build ./...\n'
        printf 'install compiled service under user runtime\n'
        ;;
      laravel)
        printf 'composer install --no-dev\n'
        printf 'php artisan config:cache\n'
        printf 'prepare PHP runtime and database variables\n'
        ;;
      flutter)
        printf 'flutter build web\n'
        printf 'serve build/web through Caddy\n'
        ;;
      container)
        printf 'podman build or podman compose up\n'
        printf 'attach logs and health checks\n'
        ;;
      static)
        printf 'serve static directory through Caddy\n'
        ;;
    esac
  done

  printf 'assign local port\n'
  printf 'write Caddy route when enabled\n'
  printf 'register monitoring endpoint\n'
}

write_plan() {
  local project_dir="$1"
  local name stack output_dir plan_file

  project_dir="$(cd -- "$project_dir" && pwd)"
  name="$(project_name "$project_dir")"
  stack="$(detect_stack "$project_dir")"
  output_dir="$ROOT_DIR/out/deploy/$name"
  plan_file="$output_dir/plan.txt"

  printf 'SevenOS Deployment Plan\n'
  printf '=======================\n'
  printf 'project: %s\n' "$name"
  printf 'path:    %s\n' "$project_dir"
  printf 'stack:   %s\n\n' "$stack"
  printf 'steps:\n'
  plan_steps "$stack" | sed 's/^/  - /'

  if is_dry_run; then
    printf '\nDry-run: plan would be written to %s\n' "$plan_file"
    return 0
  fi

  mkdir -p "$output_dir"
  {
    printf 'project=%s\n' "$name"
    printf 'path=%s\n' "$project_dir"
    printf 'stack=%s\n' "$stack"
    printf 'created=%s\n' "$(date -Iseconds)"
    printf '\nsteps:\n'
    plan_steps "$stack" | sed 's/^/- /'
  } > "$plan_file"

  log_success "Deployment plan written to $plan_file"
}

show_status() {
  local deploy_dir="$ROOT_DIR/out/deploy"

  printf 'SevenOS Deploy Status\n'
  printf '=====================\n'
  if [[ ! -d "$deploy_dir" ]]; then
    printf 'No deployment plans yet.\n'
    printf 'Create one with: seven deploy ./my-project\n'
    return 0
  fi

  find "$deploy_dir" -maxdepth 2 -name plan.txt -print | sort | while IFS= read -r plan; do
    printf '\n%s\n' "${plan#$ROOT_DIR/}"
    sed -n '1,4p' "$plan" | sed 's/^/  /'
  done
}

show_logs() {
  printf 'SevenOS Deploy Logs\n'
  printf '===================\n'
  printf 'Phase 1 writes deployment plans under out/deploy/<project>/plan.txt.\n'
  printf 'Runtime logs will be attached when container execution is enabled.\n'
}

action="${1:-plan}"
project="${2:-.}"

if [[ "$action" != "plan" && "$action" != "detect" && "$action" != "status" && "$action" != "logs" && "$action" != "-h" && "$action" != "--help" && "$action" != "help" ]]; then
  project="$action"
  action="plan"
fi

case "$action" in
  plan)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    write_plan "$project"
    ;;
  detect)
    [[ -d "$project" ]] || { log_error "Project directory not found: $project"; exit 1; }
    detect_stack "$project"
    printf '\n'
    ;;
  status) show_status ;;
  logs) show_logs ;;
  -h|--help|help) usage ;;
  *) log_error "Unknown deploy action: $action"; usage; exit 1 ;;
esac
