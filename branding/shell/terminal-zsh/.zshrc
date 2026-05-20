# SevenOS minimal terminal profile.
# Used only by seven-terminal classic/dark.

export SEVENOS_TERMINAL_COUNTRY=0
export SEVENOS_TERMINAL_CLASSIC=1
export FASTFETCH_DISABLED=1

if [[ -r "$HOME/.config/sevenos/profile-isolation.env" ]]; then
  source "$HOME/.config/sevenos/profile-isolation.env"
fi
if [[ -d "${SEVENOS_PROFILE_SHIMS:-}" && ":$PATH:" != *":$SEVENOS_PROFILE_SHIMS:"* ]]; then
  export PATH="$SEVENOS_PROFILE_SHIMS:$PATH"
fi

setopt prompt_subst
autoload -Uz colors && colors
zmodload zsh/datetime 2>/dev/null || true

typeset -g __sevenos_cmd_started=0
typeset -g __sevenos_last_duration=0
typeset -g __sevenos_last_command=""

preexec() {
  __sevenos_cmd_started="$EPOCHSECONDS"
  __sevenos_last_command="$1"
}

__sevenos_git_branch() {
  command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
  local branch
  branch="$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || true)"
  [[ -z "$branch" ]] && return 0
  local dirty=""
  git diff --quiet --ignore-submodules -- 2>/dev/null || dirty="*"
  git diff --cached --quiet --ignore-submodules -- 2>/dev/null || dirty="*"
  printf ' git:%s%s' "$branch" "$dirty"
}

__sevenos_status() {
  local exit_code="$1"
  [[ "$exit_code" -eq 0 ]] && return 0
  printf ' !%s' "$exit_code"
}

__sevenos_runtime_context() {
  local parts=()
  [[ -n "${VIRTUAL_ENV:-}" ]] && parts+=("py:${VIRTUAL_ENV:t}")
  [[ -f package.json ]] && parts+=("node")
  [[ -f Cargo.toml ]] && parts+=("rust")
  [[ -f pyproject.toml || -f requirements.txt ]] && parts+=("python")
  [[ -f Dockerfile || -f docker-compose.yml || -f compose.yml ]] && parts+=("docker")
  ((${#parts[@]})) && printf ' %s' "${parts[*]}"
}

__sevenos_terminal_mode() {
  local explicit="${SEVENOS_TERMINAL_MODE:-}"
  case "$explicit" in
    forge) print -n Forge; return ;;
    cyber) print -n Cyber; return ;;
    focus) print -n Focus; return ;;
    admin) print -n Admin; return ;;
  esac
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    print -n Admin
  elif [[ "$__sevenos_last_command" =~ '(nmap|tcpdump|wireshark|tshark|ufw|iptables|nft|ss |netstat|journalctl|auditctl)' ]]; then
    print -n Cyber
  elif command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || [[ -f package.json || -f Cargo.toml || -f pyproject.toml ]]; then
    print -n Forge
  else
    print -n Classic
  fi
}

__sevenos_duration() {
  local duration="$1"
  [[ "$duration" -ge 2 ]] && printf ' %ss' "$duration"
}

precmd() {
  local exit_code="$?"
  if [[ "$__sevenos_cmd_started" -gt 0 ]]; then
    __sevenos_last_duration=$((EPOCHSECONDS - __sevenos_cmd_started))
  else
    __sevenos_last_duration=0
  fi
  local git_info fail_info
  local mode mode_color runtime_info duration_info
  mode="$(__sevenos_terminal_mode)"
  case "$mode" in
    Cyber) mode_color=48 ;;
    Admin) mode_color=209 ;;
    Forge) mode_color=39 ;;
    Focus) mode_color=105 ;;
    *) mode_color=45 ;;
  esac
  git_info="$(__sevenos_git_branch)"
  fail_info="$(__sevenos_status "$exit_code")"
  runtime_info="$(__sevenos_runtime_context)"
  duration_info="$(__sevenos_duration "$__sevenos_last_duration")"
  PROMPT="%F{39}SevenOS%f:%F{${mode_color}}${mode}%f %F{245}%~%f%F{105}${git_info}%f%F{48}${runtime_info}%f%F{245}${duration_info}%f%F{203}${fail_info}%f"$'\n'"%F{245}%n@%m%f %F{${mode_color}}%#%f "
}
RPROMPT=''
