#!/bin/bash
# patch_config.sh - idempotently adds the orange VFR-heat settings to config.py on a
# LiveSectional Pi. Uploaded and executed by deploy-orange.ps1; safe to run more than once
# (it checks for the settings before adding them, so re-running won't duplicate lines).

set -e
CONF=/NeoSectional/config.py

if grep -q '^heat_temp_c' "$CONF"; then
    echo "heat_temp_c already present in config.py, skipping."
else
    sudo sed -i '/^max_wind_speed/a heat_temp_c = 37        #Celsius threshold (~98.6F) at/above which VFR shows orange instead of green' "$CONF"
    echo "Added heat_temp_c = 37 to config.py"
fi

if grep -q '^color_vfr_hot' "$CONF"; then
    echo "color_vfr_hot already present in config.py, skipping."
else
    sudo sed -i '/^color_vfr = /a color_vfr_hot = (255, 140, 0)   #VFR + temp >= heat_temp_c shows this orange instead of color_vfr' "$CONF"
    echo "Added color_vfr_hot = (255, 140, 0) to config.py"
fi

echo "config.py patch complete."
