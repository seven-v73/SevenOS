# SevenOS terminal country signal.
# Source this file from an interactive shell to show African country facts.

case "$-" in
  *i*) ;;
  *) return 0 2>/dev/null || exit 0 ;;
esac

if [ "${SEVENOS_TERMINAL_COUNTRY:-1}" = "0" ]; then
  if [ "${SEVENOS_TERMINAL_CLASSIC:-0}" = "1" ] && [ "${SEVENOS_TERMINAL_CLASSIC_PROMPT:-1}" != "0" ]; then
    if [ -n "${ZSH_VERSION:-}" ]; then
      PROMPT='%m:%1~ %n%# '
    elif [ -n "${BASH_VERSION:-}" ]; then
      PS1='\h:\W \u\$ '
    fi
  fi
  return 0 2>/dev/null || exit 0
fi

__sevenos_country_command() {
  if command -v seven-country >/dev/null 2>&1; then
    seven-country "$1"
  elif [ -x "$HOME/.local/bin/seven-country" ]; then
    "$HOME/.local/bin/seven-country" "$1"
  fi
}

if [ -z "${SEVENOS_TERMINAL_COUNTRY_SHOWN:-}" ]; then
  export SEVENOS_TERMINAL_COUNTRY_SHOWN=1
  __sevenos_country_command open
fi

__sevenos_terminal_country_close() {
  __sevenos_country_command close
}

if [ -n "${ZSH_VERSION:-}" ]; then
  if ! functions zshexit >/dev/null 2>&1; then
    zshexit() {
      __sevenos_terminal_country_close
    }
  fi
elif [ -n "${BASH_VERSION:-}" ]; then
  if [ -z "$(trap -p EXIT)" ]; then
    trap '__sevenos_terminal_country_close' EXIT
  fi
fi
