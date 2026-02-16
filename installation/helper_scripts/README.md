# Scripts

---

## 1) Fake Hostname Prompt

Changes your **terminal prompt hostname** (does not change the real system hostname).

📄 **Script:** **[change_host_name.sh](./change_host_name.sh)**  

Run:
```bash
source ./change_host_name ueransim
```

---

## 2) Timeshift Snapshot Creator

Creates a Timeshift snapshot.

📄 **Script:** **[make_timeshift_snapshot.sh](./make_timeshift_snapshot.sh)**  
📚 **Docs:** **[docs/make_timeshift_snapshot.md](../docs/make_timeshift_snapshot.md)**


Run:
```bash
chmod +x make_timeshift_snapshot
sudo ./make_timeshift_snapshot "My snapshot name"
```


## 3) bash_helper.sh — Tiny Bash UI helpers (prompts, pretty output)

`bash_helper.sh` provides reusable functions like **titles**, **yes/no prompts**, **print+run commands**, **pause**, and a simple **sudo check**.

It’s meant to be **sourced** by your other scripts.

📄 **Script:** **[bash_helper.sh](./bash_helper.sh)**  
📚 **Docs:** **[docs/bash_helper.md](./docs/scripts/bash_helper.md)**

Run (source it from another script):
```bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/helper_scripts/bash_helper.sh"

```

---