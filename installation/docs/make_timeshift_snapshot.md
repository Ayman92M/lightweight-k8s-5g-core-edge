# Timeshift Snapshot Creator (Ubuntu/Debian)

Simple script to install **Timeshift** (if needed) and create a **Timeshift snapshot** using `rsync`.

---

## Script

👉 **[make_timeshift_snapshot.sh](./make_timeshift_snapshot.sh)**

---

## Usage
```bash
sudo ./make_timeshift_snapshot.sh "My snapshot name"
```


The script will:
- Update apt
- Install `timeshift` + `rsync` if missing
- Detect your root device (`/`)
- Create the snapshot with your description
- List snapshots to confirm

---

## Useful Timeshift commands

Install Timeshift
```bash
sudo apt update
sudo apt install -y timeshift
```

Find your root device
```bash
ROOTDEV=$(findmnt -n -o SOURCE /)
```

Create a CLEAN BASELINE snapshot
```bash
sudo timeshift --rsync --snapshot-device "$ROOTDEV" --create --comments "CLEAN BASELINE"
```

List snapshots:
```bash
sudo timeshift --list
```

Show config:
```bash
sudo cat /etc/timeshift/timeshift.json
```

Delete a snapshot:
```bash
sudo timeshift --delete --snapshot 'SNAPSHOT_NAME'
```

Restore a snapshot:
```bash
sudo timeshift --restore --snapshot 'SNAPSHOT_NAME'
```

---

