#!/bin/sh
set -e

echo "================================================"
echo "  XYIDactyl Agent"
echo "  Starting up..."
echo "================================================"

# Ensure we are in the container volume
cd /home/container || echo "Could not cd to /home/container, using current directory"

# Create default control.json if it doesn't exist
mkdir -p ./control
if [ ! -f ./control/control.json ]; then
    echo '{"version":0,"updated_at":0,"users":[],"alerts":[],"automations":[]}' > ./control/control.json
    echo "[INIT] Created default control.json"
fi

# Ensure data directories exist
mkdir -p ./data/logs

echo "[INIT] Configuration:"
echo "  PANEL_URL=${PANEL_URL}"
echo "  SAMPLING_INTERVAL=${SAMPLING_INTERVAL:-30}s"
echo "  RETENTION_DAYS=${RETENTION_DAYS:-30}"
echo "  PUSH_PROVIDER=${PUSH_PROVIDER:-dev}"
echo "  AGENT_UUID=${AGENT_UUID}"

# Start the agent
exec /app/xyidactyl-agent
