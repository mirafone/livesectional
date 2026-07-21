# Deploying the Orange VFR-Heat Update to Your Maps

Two maps, both running LiveSectional from `/NeoSectional/` on the Pi's SD card:

| Map | IP | SSH |
|---|---|---|
| AZ | 192.168.49.146 | `pi@192.168.49.146` |
| NV/CA | 192.168.49.54 | `pi@192.168.49.54` |

SSH username: `pi`. Password is not stored in this repo or the script — you'll be prompted for it by `ssh`/`scp` each time.

**Important:** the built-in "check for update" button in LiveSectional's web UI pulls from `livesectional.com`'s own server, not this GitHub fork. It will never see these changes — don't use it here.

Only two files actually changed: `metar-v4.py` (logic) and `config.py` (two new settings: `heat_temp_c` and `color_vfr_hot`). Everything else on each Pi — your saved `airports` file, the rest of `config.py`, `hmdata`, and anything under `profiles/` — is left untouched.

## Fast path: run the script

From this repo's root (`D:\Git\livesectional`), in PowerShell:

```powershell
.\deploy-orange.ps1 -MapIP 192.168.49.146 -MapName AZ
```

Watch the LED map through one full update cycle (`update_interval`, default 15 minutes) to confirm normal airports still display correctly. Once you're satisfied, do the second map:

```powershell
.\deploy-orange.ps1 -MapIP 192.168.49.54 -MapName NVCA
```

Do them one at a time, not in parallel — confirm the first is stable before touching the second.

### What the script does, in order

1. Backs up `/NeoSectional` on the Pi's own SD card to `/NeoSectional-backup-<timestamp>`. This is your rollback point.
2. Also copies `config.py`, `airports`, and `hmdata` down to `backups\<MapName>-<timestamp>\` in this repo, in case the SD card itself ever has problems.
3. Uploads the updated `metar-v4.py`.
4. Runs `patch_config.sh` on the Pi, which adds the two new lines to `config.py` (idempotent — safe to re-run, checks before adding).
5. Kills the running `metar-v4.py` / `metar-display-v4.py` / `check-display.py` processes and restarts them via `startup.py`.

### Rollback

If anything looks wrong after deploying:

```powershell
.\deploy-orange.ps1 -MapIP 192.168.49.146 -MapName AZ -Rollback
```

This finds the most recent `/NeoSectional-backup-*` on that Pi, replaces the live `/NeoSectional` with it, and restarts the display — you're back to exactly where you started, saved airports and all.

## Manual path (if you'd rather not use the script)

```bash
ssh pi@192.168.49.146

# 1. Backup - this is your rollback point
sudo cp -r /NeoSectional /NeoSectional-backup-$(date +%Y%m%d)

# 2. exit and pull a local copy too, from your machine
exit
scp pi@192.168.49.146:/NeoSectional/config.py .\backups\AZ-config.py
scp pi@192.168.49.146:/NeoSectional/airports .\backups\AZ-airports
scp pi@192.168.49.146:/NeoSectional/hmdata .\backups\AZ-hmdata

# 3. push the updated file
scp D:\Git\livesectional\metar-v4.py pi@192.168.49.146:/NeoSectional/metar-v4.py

# 4. SSH back in and hand-add the two lines to config.py
ssh pi@192.168.49.146
nano /NeoSectional/config.py
#   under max_wind_speed, add:
#     heat_temp_c = 37        #Celsius threshold (~98.6F) at/above which VFR shows orange instead of green
#   under color_vfr, add:
#     color_vfr_hot = (255, 140, 0)   #VFR + temp >= heat_temp_c shows this orange instead of color_vfr

# 5. restart the display processes
sudo pkill -f metar-v4.py; sudo pkill -f metar-display-v4.py; sudo pkill -f check-display.py
sleep 1
sudo python3 /NeoSectional/startup.py run &
```

Manual rollback:

```bash
ssh pi@192.168.49.146
sudo rm -rf /NeoSectional
sudo cp -r /NeoSectional-backup-<date> /NeoSectional
sudo pkill -f metar-v4.py; sudo pkill -f metar-display-v4.py; sudo pkill -f check-display.py
sleep 1
sudo python3 /NeoSectional/startup.py run &
```

## Repeat for the second map

Same steps, swap in `192.168.49.54` (NV/CA) for the IP and `NVCA` for the backup label.
