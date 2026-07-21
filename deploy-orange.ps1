<#
.SYNOPSIS
  Deploys the orange-VFR-heat update (metar-v4.py + two new config.py settings) to a
  LiveSectional map over SSH, and can roll it back.

.DESCRIPTION
  Does NOT touch your saved airports, config.py values, or hmdata beyond adding the two
  new settings (heat_temp_c, color_vfr_hot). Every run starts with a full backup of
  /NeoSectional on the Pi's SD card (your rollback point) plus a local copy of
  config.py / airports / hmdata pulled down to this machine.

  You'll be prompted for the 'pi' account password by ssh/scp as needed - it is not
  stored anywhere in this script or repo.

.PARAMETER MapIP
  IP address of the target Raspberry Pi.

.PARAMETER MapName
  Friendly label used for backup folder naming, e.g. "AZ" or "NVCA".

.PARAMETER Rollback
  If set, restores the most recent /NeoSectional-backup-* found on the Pi instead of deploying.

.EXAMPLE
  .\deploy-orange.ps1 -MapIP 192.168.49.146 -MapName AZ

.EXAMPLE
  .\deploy-orange.ps1 -MapIP 192.168.49.146 -MapName AZ -Rollback
#>

param(
    [Parameter(Mandatory = $true)][string]$MapIP,
    [Parameter(Mandatory = $true)][string]$MapName,
    [switch]$Rollback
)

$SshUser         = "pi"
$Target          = "$SshUser@$MapIP"
$RemoteDir       = "/NeoSectional"
$RepoDir         = "D:\Git\livesectional"
$LocalBackupRoot = "$RepoDir\backups\$MapName-$(Get-Date -Format yyyyMMdd-HHmmss)"

function Restart-Map {
    Write-Host "`nRestarting display processes on $MapName..."
    ssh $Target "sudo pkill -f metar-v4.py; sudo pkill -f metar-display-v4.py; sudo pkill -f check-display.py; sleep 1; sudo python3 $RemoteDir/startup.py run > /dev/null 2>&1 &"
}

if ($Rollback) {
    Write-Host "=== ROLLBACK: $MapName ($MapIP) ==="
    $latest = (ssh $Target "ls -1d /NeoSectional-backup-* 2>/dev/null | sort | tail -1").Trim()
    if ([string]::IsNullOrWhiteSpace($latest)) {
        Write-Error "No backup found on $MapIP (looked for /NeoSectional-backup-*). Aborting rollback."
        exit 1
    }
    Write-Host "Restoring from $latest ..."
    ssh $Target "sudo rm -rf $RemoteDir && sudo cp -r $latest $RemoteDir"
    Restart-Map
    Write-Host "`nRollback complete. $MapName restored from $latest."
    exit 0
}

Write-Host "=== Deploying orange-VFR-heat update to $MapName ($MapIP) ==="
Write-Host "You'll be prompted for the 'pi' password by ssh/scp a few times below.`n"

# 1. Remote backup on the SD card - this is your rollback point.
$remoteBackup = "/NeoSectional-backup-$(Get-Date -Format yyyyMMdd-HHmmss)"
Write-Host "1) Backing up $RemoteDir to $remoteBackup on the Pi..."
ssh $Target "sudo cp -r $RemoteDir $remoteBackup"

# 2. Pull a local copy of the user-data files too, in case the SD card has issues later.
Write-Host "2) Copying config.py / airports / hmdata locally to $LocalBackupRoot ..."
New-Item -ItemType Directory -Force -Path $LocalBackupRoot | Out-Null
scp "${Target}:$RemoteDir/config.py" "$LocalBackupRoot\config.py"
scp "${Target}:$RemoteDir/airports" "$LocalBackupRoot\airports"
scp "${Target}:$RemoteDir/hmdata" "$LocalBackupRoot\hmdata"

# 3. Push the updated metar-v4.py (only file with real logic changes).
Write-Host "3) Uploading updated metar-v4.py ..."
scp "$RepoDir\metar-v4.py" "${Target}:$RemoteDir/metar-v4.py"

# 4. Patch config.py in place - adds heat_temp_c + color_vfr_hot only, leaves everything
#    else (your saved airports/settings) untouched.
Write-Host "4) Patching config.py on the Pi (adds heat_temp_c + color_vfr_hot only) ..."
scp "$RepoDir\patch_config.sh" "${Target}:/tmp/patch_config.sh"
ssh $Target "chmod +x /tmp/patch_config.sh && /tmp/patch_config.sh && rm /tmp/patch_config.sh"

# 5. Restart the display processes so the new code takes effect.
Restart-Map

Write-Host "`n=== Deploy complete for $MapName ==="
Write-Host "Remote backup: $remoteBackup"
Write-Host "Local backup:  $LocalBackupRoot"
Write-Host "Watch it through one full update cycle (config.py's update_interval, default 15 min) before moving to the next map."
Write-Host "Rollback with: .\deploy-orange.ps1 -MapIP $MapIP -MapName $MapName -Rollback"
