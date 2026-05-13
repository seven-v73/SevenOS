#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="${SEVENOS_ROOT:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$ROOT_DIR/scripts/lib.sh"

JSON_OUTPUT=0
RECORD_HISTORY=0
score_total=0
score_max=0
declare -a recommendations=()
declare -a category_names=()
declare -A category_total=()
declare -A category_max=()
current_category=""

usage() {
  cat <<'EOF'
SevenOS readiness scorecard

Usage:
  seven readiness [--json] [--record]
  ./scripts/readiness.sh [--json] [--record]

Options:
  --json      Print machine-readable summary only
  --record    Append summary to out/readiness/history.tsv
EOF
}

for arg in "$@"; do
  case "$arg" in
    --json) JSON_OUTPUT=1 ;;
    --record) RECORD_HISTORY=1 ;;
    -h|--help|help) usage; exit 0 ;;
    *) log_error "Unknown readiness option: $arg"; usage; exit 1 ;;
  esac
done

criterion() {
  local name="$1"
  current_category="$name"
  if [[ -z "${category_max[$name]+set}" ]]; then
    category_names+=("$name")
    category_total[$name]=0
    category_max[$name]=0
  fi
  [[ "$JSON_OUTPUT" -eq 1 ]] || printf '\n== %s ==\n' "$name"
}

pass() {
  local message="$1"
  [[ "$JSON_OUTPUT" -eq 1 ]] || printf '[OK] %s\n' "$message"
  score_total=$((score_total + 1))
  score_max=$((score_max + 1))
  category_total[$current_category]=$((category_total[$current_category] + 1))
  category_max[$current_category]=$((category_max[$current_category] + 1))
}

partial() {
  local message="$1"
  [[ "$JSON_OUTPUT" -eq 1 ]] || printf '[PART] %s\n' "$message"
  score_max=$((score_max + 1))
  category_max[$current_category]=$((category_max[$current_category] + 1))
}

miss() {
  local message="$1"
  [[ "$JSON_OUTPUT" -eq 1 ]] || printf '[MISS] %s\n' "$message"
  score_max=$((score_max + 1))
  category_max[$current_category]=$((category_max[$current_category] + 1))
}

recommend() {
  local command="$1"
  local reason="$2"
  recommendations+=("$command|$reason")
}

command_ready() {
  local command_name="$1"
  command -v "$command_name" >/dev/null 2>&1 || [[ -x "$ROOT_DIR/bin/$command_name" ]]
}

package_ready() {
  local package="$1"
  pacman -Q "$package" >/dev/null 2>&1
}

service_active() {
  local service="$1"
  systemctl is-active --quiet "$service" 2>/dev/null
}

file_ready() {
  [[ -s "$1" ]]
}

profile_state() {
  local package_file="$1"
  local installed=0
  local total=0
  local package

  while IFS= read -r package; do
    package="${package%%#*}"
    package="${package//[[:space:]]/}"
    [[ -z "$package" ]] && continue
    total=$((total + 1))
    package_ready "$package" && installed=$((installed + 1))
  done < "$package_file"

  if [[ "$total" -eq 0 ]]; then
    printf 'MISS 0/0'
  elif [[ "$installed" -eq "$total" ]]; then
    printf 'OK %s/%s' "$installed" "$total"
  elif [[ "$installed" -gt 0 ]]; then
    printf 'PART %s/%s' "$installed" "$total"
  else
    printf 'MISS 0/%s' "$total"
  fi
}

profile_check() {
  local label="$1"
  local package_file="$2"
  local recommendation="${3:-}"
  local state

  state="$(profile_state "$package_file")"
  case "$state" in
    OK*) pass "$label profile installed ($state)" ;;
    PART*)
      partial "$label profile partial ($state)"
      if [[ "$recommendation" == "seven improve target" ]]; then
        recommend "$recommendation" "complete role workspaces"
      elif [[ -n "$recommendation" ]]; then
        recommend "$recommendation" "complete $label workspace"
      fi
      ;;
    *)
      miss "$label profile missing ($state)"
      if [[ "$recommendation" == "seven improve target" ]]; then
        recommend "$recommendation" "install role workspaces"
      elif [[ -n "$recommendation" ]]; then
        recommend "$recommendation" "install $label workspace"
      fi
      ;;
  esac
}

if [[ "$JSON_OUTPUT" -ne 1 ]]; then
  printf 'SevenOS Readiness Scorecard\n'
  printf '===========================\n'
  printf 'Criteria: performance, UX/UI, compatibility, ease, security, customization, target use, ecosystem.\n'
fi

criterion "Performance"
memory_kb="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
memory_gb="$((memory_kb / 1024 / 1024))"
if (( memory_gb >= 16 )); then pass "RAM ${memory_gb}GB"; elif (( memory_gb >= 8 )); then partial "RAM ${memory_gb}GB, usable"; else miss "RAM ${memory_gb}GB"; fi
command_ready hyprctl || package_ready hyprland && pass "Hyprland available" || miss "Hyprland missing"
command_ready waybar && pass "Waybar available" || miss "Waybar missing"
grep -Eiq '(vmx|svm)' /proc/cpuinfo && pass "CPU virtualization available" || partial "CPU virtualization not detected"

criterion "UX/UI"
file_ready "$ROOT_DIR/hyprland/rofi/sevenos.rasi" && pass "SevenOS Rofi theme present" || miss "Rofi theme missing"
file_ready "$ROOT_DIR/hyprland/rofi/power.rasi" && pass "Power menu theme present" || miss "Power menu theme missing"
file_ready "$ROOT_DIR/hyprland/mako/config" && pass "Mako notification theme present" || miss "Mako theme missing"
command_ready seven-welcome && pass "Welcome flow available" || partial "Welcome flow not installed in PATH"
command_ready seven-power && pass "Power flow available" || partial "Power flow not installed in PATH"

criterion "Software Compatibility"
profile_check "Windows" "$ROOT_DIR/scripts/packages-windows.txt" "seven improve compatibility"
command_ready virt-manager && pass "Virt Manager available" || { partial "Virt Manager not installed"; recommend "seven improve compatibility" "complete Windows Mode and VM tooling"; }
command_ready flatpak && pass "Flatpak available" || { partial "Flatpak not installed"; recommend "seven improve compatibility" "install app compatibility layer"; }
command_ready wine && pass "Wine available" || { partial "Wine not installed"; recommend "seven improve compatibility" "install Windows app compatibility"; }
[[ -x "$ROOT_DIR/vm/windows-mode.sh" ]] && pass "Windows Mode assistant available" || { miss "Windows Mode assistant missing"; recommend "seven improve compatibility" "restore Windows Mode assistant"; }

criterion "Ease Of Use"
command_ready seven && pass "seven controller available" || partial "seven controller only available in repo"
command_ready sevenpkg && pass "sevenpkg available" || partial "sevenpkg only available in repo"
[[ -x "$ROOT_DIR/seven-hub/bin/seven-hub" ]] && pass "Seven Hub available" || miss "Seven Hub missing"
file_ready "$ROOT_DIR/docs/UX_PRINCIPLES.md" && pass "UX principles documented" || miss "UX principles missing"

criterion "Security"
package_ready ufw && pass "UFW installed" || { miss "UFW missing"; recommend "seven improve security" "install firewall and hardening tools"; }
service_active ufw.service && pass "UFW active" || { partial "UFW not active"; recommend "seven improve security --apply" "enable base hardening when ready"; }
package_ready firejail && pass "Firejail installed" || { partial "Firejail missing"; recommend "seven improve security" "install cyber lab isolation"; }
package_ready bubblewrap && pass "Bubblewrap installed" || { partial "Bubblewrap missing"; recommend "seven improve security" "install sandbox backend"; }
file_ready "$ROOT_DIR/security/cyber-policy.md" && pass "Cyber policy documented" || miss "Cyber policy missing"

criterion "Customization"
file_ready "$ROOT_DIR/identity/README.md" && pass "Identity system documented" || miss "Identity docs missing"
file_ready "$ROOT_DIR/identity/palette.sh" && pass "Palette source present" || miss "Palette missing"
file_ready "$ROOT_DIR/hyprland/hyprland.conf" && pass "Hyprland config present" || miss "Hyprland config missing"
file_ready "$ROOT_DIR/identity/assets/logo-sevenos.svg" && pass "SevenOS logo present" || miss "SevenOS logo missing"

criterion "Target Use"
profile_check "Forge" "$ROOT_DIR/scripts/packages-dev.txt" "seven improve target"
profile_check "Shield" "$ROOT_DIR/scripts/packages-cybersecurity.txt" "seven improve target"
profile_check "Studio" "$ROOT_DIR/scripts/packages-creation.txt" "seven improve target"
file_ready "$ROOT_DIR/sevenpkg/metapackages.json" && pass "Meta-packages declared" || miss "Meta-packages missing"

criterion "Ecosystem"
file_ready "$ROOT_DIR/docs/VISION.md" && pass "Vision documented" || miss "Vision missing"
file_ready "$ROOT_DIR/docs/PRODUCT_STRATEGY.md" && pass "Product strategy documented" || miss "Product strategy missing"
file_ready "$ROOT_DIR/docs/OS_CRITERIA.md" && pass "OS choice criteria documented" || miss "OS criteria missing"
file_ready "$ROOT_DIR/archiso/README.md" && pass "ISO path documented" || miss "ISO docs missing"
file_ready "$ROOT_DIR/installer/README.md" && pass "Installer path documented" || miss "Installer docs missing"

percent=$((score_total * 100 / score_max))

record_history() {
  local history_dir="$ROOT_DIR/out/readiness"
  local history_file="$history_dir/history.tsv"

  if is_dry_run; then
    [[ "$JSON_OUTPUT" -eq 1 ]] || log_info "Dry-run: readiness history would be written to $history_file"
    return
  fi

  mkdir -p "$history_dir"
  printf '%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$score_total" "$score_max" "$percent" >> "$history_file"
}

print_json() {
  local first=1
  local seen_key
  declare -A seen_recommendations=()
  printf '{'
  printf '"score":%s,' "$score_total"
  printf '"max":%s,' "$score_max"
  printf '"percent":%s,' "$percent"
  printf '"categories":{'
  for category in "${category_names[@]}"; do
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    printf '"%s":{"score":%s,"max":%s,"percent":%s}' \
      "$category" \
      "${category_total[$category]}" \
      "${category_max[$category]}" \
      "$((category_total[$category] * 100 / category_max[$category]))"
  done
  printf '},'
  printf '"recommendations":['
  first=1
  for item in "${recommendations[@]}"; do
    command="${item%%|*}"
    reason="${item#*|}"
    seen_key="$command|$reason"
    [[ -z "${seen_recommendations[$seen_key]+set}" ]] || continue
    seen_recommendations[$seen_key]=1
    [[ "$first" -eq 1 ]] || printf ','
    first=0
    printf '{"command":"%s","reason":"%s"}' "$command" "$reason"
  done
  printf ']}\n'
}

if [[ "$RECORD_HISTORY" -eq 1 ]]; then
  record_history
fi

if [[ "$JSON_OUTPUT" -eq 1 ]]; then
  print_json
  exit 0
fi

printf '\n== Category Scores ==\n'
for category in "${category_names[@]}"; do
  printf '  %-24s %2s/%-2s %3s%%\n' \
    "$category" \
    "${category_total[$category]}" \
    "${category_max[$category]}" \
    "$((category_total[$category] * 100 / category_max[$category]))"
done

printf '\n== Summary ==\n'
printf 'Score: %s/%s (%s%%)\n' "$score_total" "$score_max" "$percent"

if [[ "$score_total" -eq "$score_max" ]]; then
  log_success "SevenOS covers all OS choice criteria on this machine."
elif (( score_total * 100 / score_max >= 70 )); then
  log_warn "SevenOS covers most criteria; complete missing profiles/services for a premium setup."
else
  log_warn "SevenOS foundations are present, but this machine needs more setup for the full experience."
fi

if [[ "${#recommendations[@]}" -gt 0 ]]; then
  printf '\n== Recommended Improvements ==\n'
  printf '%s\n' "${recommendations[@]}" | awk -F'|' '!seen[$1]++ {printf "  %-34s %s\n", $1, $2}'
fi
