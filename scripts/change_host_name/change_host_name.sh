#!/usr/bin/env bash
set -e

# Usage:
#   source ./change_host_name.sh ueransim
# OR:
#   ./change_host_name.sh ueransim  (will update bashrc, but won't change current prompt instantly)

FAKEHOST="$1"

if [[ -z "$FAKEHOST" ]]; then
  echo "❌ Usage:"
  echo "   source ./change_host_name.sh <fake_hostname>"
  echo ""
  echo "Example:"
  echo "   source ./change_host_name.sh ueran"
  return 1 2>/dev/null || exit 1
fi

BASHRC="$HOME/.bashrc"

START_MARKER="# >>> fake-hostname-prompt >>>"
END_MARKER="# <<< fake-hostname-prompt <<<"

PROMPT_LINE="PS1='\${debian_chroot:+(\$debian_chroot)}\\[\\033[01;32m\\]\\u@${FAKEHOST}\\[\\033[00m\\]:\\[\\033[01;34m\\]\\w\\[\\033[00m\\]\\$ '"

# Remove old block if it exists
if grep -qF "$START_MARKER" "$BASHRC"; then
  sed -i "/$START_MARKER/,/$END_MARKER/d" "$BASHRC"
fi

# Append new block at the bottom
{
  echo ""
  echo "$START_MARKER"
  echo "$PROMPT_LINE"
  echo "$END_MARKER"
} >> "$BASHRC"

echo "✅ Updated ~/.bashrc with fake hostname: $FAKEHOST"

# Activate immediately ONLY if script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  source "$BASHRC"
  echo "✅ Activated in this terminal!"
else
  echo "⚠️ To activate in THIS terminal, run:"
  echo "   source ~/.bashrc"
  echo "✅ Or run the script like this next time:"
  echo "   source ./change_host_name.sh $FAKEHOST"
fi

#PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@ueransim\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
