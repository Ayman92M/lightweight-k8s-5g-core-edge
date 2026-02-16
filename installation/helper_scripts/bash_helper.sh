#!/usr/bin/env bash
# bash_helper.sh - tiny bash UI helpers:
# title, command, ask_yn, pause, do_step, need_sudo

set -u

# ---- colors (auto-disable if not a TTY or NO_COLOR is set) ----
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  _BOLD=$'\e[1m'
  _DIM=$'\e[2m'
  _REV=$'\e[7m'     # <-- invert (reverse video)
  _REV_OFF=$'\e[27m' # <-- optional: turn off reverse only
  _RST=$'\e[0m'

  _C_TITLE=$'\e[38;5;45m'
  _C_CMD=$'\e[38;5;214m'
  _C_OK=$'\e[38;5;82m'
  _C_WARN=$'\e[38;5;203m'
  _C_INFO=$'\e[38;5;117m'
else
  _BOLD=""; _DIM=""; _REV=""; _REV_OFF=""; _RST=""
  _C_TITLE=""; _C_CMD=""; _C_OK=""; _C_WARN=""; _C_INFO=""
fi


# ---- base helpers ----
title() {
  local msg="${1:-}"
  printf "\n%s  %s  %s  %s\n" "${_BOLD}${_REV}" "$msg" "${_RST}"
}



ok()   { printf "%s✔  %s%s\n" "${_BOLD}${_C_OK}"   "${1:-OK}"      "${_RST}"; printf "\n"; }
warn() { printf "%s!  %s%s\n" "${_BOLD}${_C_WARN}" "${1:-Warning}" "${_RST}"; printf "\n"; }
info() { printf "ℹ  %s\n" "${1:-}"; }



command() {
  # Usage:
  #   command "ls -la"
  #   command --run "ls -la"
  local run=0
  if [[ "${1:-}" == "--run" ]]; then
    run=1
    shift
  fi

  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    warn "command(): missing command string"
    return 2
  fi

  printf "%s>>> $ %s%s\n" "${_BOLD}${_C_CMD}" "$cmd" "${_RST}"

  if (( run )); then
    # Supports pipes/redirects/etc.
    eval "$cmd"
    printf "\n"
  fi
}

ask_yn() {
  # Usage:
  #   if ask_yn "Continue?" Y; then ...; fi
  #   ask_yn "Continue?" N
  local prompt="${1:-Are you sure?}"
  local default="${2:-Y}"
  local hint ans

  case "${default^^}" in
    Y) hint="[Y/n]" ;;
    N) hint="[y/N]" ;;
    *) hint="[y/n]" ;;
  esac

  while true; do
    printf "%s%s? %s%s " "${_BOLD}" "$prompt" "$hint" "${_RST}"
    IFS= read -r ans || return 1

    if [[ -z "$ans" ]]; then
      [[ "${default^^}" == "Y" ]] && return 0
      [[ "${default^^}" == "N" ]] && return 1
      continue
    fi

    case "${ans,,}" in
      y|yes) return 0 ;;
      n|no)  return 1 ;;
      *) printf "%sPlease answer y or n.%s\n" "${_C_WARN}" "${_RST}" ;;
    esac
  done
}

pause() {
  # Usage: pause "Optional message"
  local msg="${1:-Press Enter to continue...}"
  printf "%s%s%s " "${_DIM}" "$msg" "${_RST}"
  IFS= read -r _ || true
}

do_step() {
  # Usage:
  #   do_step "Open browser and login" "Then go to Settings → API Keys"
  # Returns: 0 (done), 1 (abort)

  local what="${1:-}"
  local note="${2:-}"
  local ans

  printf "%s%s%s\n" "${_BOLD}${_C_INFO}" ">>> ACTION REQUIRED" "${_RST}"
  printf "%s- %s%s\n" "${_C_INFO}" "$what" "${_RST}"
  [[ -n "$note" ]] && printf "%s  %s%s\n" "${_DIM}" "$note" "${_RST}"

  while true; do
    printf "%sPress Enter when done (or type 'q' to abort):%s " "${_DIM}" "${_RST}"
    IFS= read -r ans || return 1
    case "${ans,,}" in
      "" ) return 0 ;;
      q|quit|exit) return 1 ;;
      *) printf "%sJust press Enter when done, or type q to abort.%s\n" "${_C_WARN}" "${_RST}" ;;
    esac
  done
}

need_sudo() {
  # Simple sudo check (returns 0/1; does not exit)
  if [[ "$(id -u)" -eq 0 ]]; then
    return 0
  fi

  # IMPORTANT: our function is named "command", so use builtin command here
  builtin command -v sudo >/dev/null 2>&1 || { warn "sudo not found"; return 1; }

  # no-prompt attempt first
  sudo -n true >/dev/null 2>&1 && return 0

  # prompt user (interactive)
  do_step "This step needs sudo. Enter your password when prompted." ""
  sudo -v >/dev/null 2>&1 || { warn "sudo failed"; return 1; }
  return 0
}


apt_update() {
  title "--- Updating package lists ---"
  command --run "sudo apt-get update"
}


die() { echo "ERROR: $*" >&2; exit 1; }

source_or_die() {
  local file="$1"
  [[ -n "$file" ]] || die "source_or_die: missing filepath"
  [[ -f "$file" ]] || die "Missing file: $file"
  # shellcheck source=/dev/null
  source "$file" || die "Failed to source: $file"
}
