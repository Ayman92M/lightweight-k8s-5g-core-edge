# bash_helper.sh — Tiny Bash UI helpers (prompts, pretty output)

`bash_helper.sh` provides reusable functions like **titles**, **yes/no prompts**, **print+run commands**, **pause**, and a simple **sudo check**.

It’s meant to be **sourced** by your other scripts.

---


## How to use (source it)

In any script that wants these helpers:

```bash
#!/usr/bin/env bash
set -e

# Example path when scripts are in sibling folders:

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helper_scripts/bash_helper.sh"

```

---

## What’s inside

Functions you can use:

- `title "Message"`  
  Prints a section header.

- `info "Message"`  
  Prints an info line.

- `ok "Message"` / `warn "Message"`  
  Prints a success or warning line.

- `command "cmd"`  
  Prints a command (does not run it).

- `command --run "cmd"`  
  Prints the command and runs it (supports pipes/redirects via `eval`).

- `ask_yn "Question" [Y|N]`  
  Asks a yes/no question. Returns **0** for yes, **1** for no.

- `pause ["Message"]`  
  Waits for Enter.

- `do_step "What to do" ["Note"]`  
  Prints an “ACTION REQUIRED” block and waits for Enter (or `q` to abort).  
  Returns **0** when done, **1** if aborted.

- `need_sudo`  
  Checks/requests sudo. Returns **0** if sudo is available, **1** if it fails.

---

