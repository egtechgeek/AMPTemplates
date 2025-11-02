#!/bin/bash

# Resolve script path and working directory
SCRIPT_NAME=$(readlink -f "$0")
SCRIPTDIR=$(dirname "$SCRIPT_NAME")

###############################################################################
# Ensure XDG_RUNTIME_DIR exists and is valid (for Wine in headless Docker)
#
# In Docker/AMP there is usually no systemd user session, so Wine and
# winetricks complain:
#   "XDG_RUNTIME_DIR is invalid or not set in the environment"
#
# We'll create a per-container runtime dir under /tmp and lock it down.
###############################################################################
if [ -z "$XDG_RUNTIME_DIR" ]; then
    export XDG_RUNTIME_DIR="/tmp/xdg-runtime-dir"
fi

if [ ! -d "$XDG_RUNTIME_DIR" ]; then
    mkdir -p "$XDG_RUNTIME_DIR"
fi

chmod 700 "$XDG_RUNTIME_DIR"
chown "$(id -u)":"$(id -g)" "$XDG_RUNTIME_DIR"

###############################################################################
# Start a headless X server (Xvfb), capture the dynamic display number,
# and point DISPLAY at it so Wine/winetricks can run GUI setup steps.
###############################################################################

# Open fd 6 to capture Xvfb's chosen display number
exec 6>display.log

# Launch Xvfb. -displayfd 6 means "write :<num> to fd 6".
# -nolisten tcp / -nolisten unix keeps it local-only and more locked down.
# (Some distros don't support -nolisten unix, but leaving it is harmless.)
/usr/bin/Xvfb -displayfd 6 -nolisten tcp -nolisten unix &
XVFB_PID=$!

# Wait until Xvfb writes the display number
while [[ ! -s display.log ]]; do
  sleep 1
done

# Read the display number (like ":99") from the file
read -r DPY_NUM < display.log
rm -f display.log

###############################################################################
# Wine environment setup
###############################################################################

export WINEPREFIX="$SCRIPTDIR/renegadex/.wine"
export WINEDLLOVERRIDES="mscoree,mshtml="
export WINEARCH=win64
export WINEDEBUG=fixme-all
export DISPLAY="$DPY_NUM"

###############################################################################
# Prepare winetricks (grab latest helper script)
###############################################################################

wget -q -N https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks
chmod +x winetricks

###############################################################################
# Install required runtime components quietly via winetricks
#
# We split packages into two passes to match your original logic.
###############################################################################

# First batch
PACKAGES="corefonts vcrun2008 vcrun2010 xact d3dcompiler_43 d3dx9 msxml3"

# Fresh log file
echo "" > winescript_log.txt 2>&1

for PACKAGE in $PACKAGES; do
  ./winetricks -q "$PACKAGE" >> winescript_log.txt 2>&1
done

# Second batch (note: you had win7, dotnet452, win7)
PACKAGES="win7 dotnet452 win7"
for PACKAGE in $PACKAGES; do
  ./winetricks -q "$PACKAGE" >> winescript_log.txt 2>&1
done

# Clean winetricks/fontconfig cache to keep the container lean
rm -rf ~/.cache/winetricks ~/.cache/fontconfig

###############################################################################
# Shutdown Xvfb and clean up
###############################################################################

# Close fd 6
exec 6>&-

# Kill the virtual X server
kill "$XVFB_PID"

exit 0
