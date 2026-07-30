#!/usr/bin/env bash
# Run this after providing DATABASE_URL from .12
# Usage: bash complete-setup.sh "postgresql://opencut:PASSWORD@192.168.0.12:5432/opencut"
set -e

DBURL="${1:-}"
if [ -z "$DBURL" ]; then
  # Try reading from /tmp/opencut_dburl.txt if scp succeeded
  if [ -f /tmp/opencut_dburl.txt ]; then
    DBURL=$(grep '^DATABASE_URL=' /tmp/opencut_dburl.txt | cut -d= -f2-)
    echo "Read DATABASE_URL from /tmp/opencut_dburl.txt"
  else
    echo "Usage: $0 'postgresql://opencut:PASSWORD@192.168.0.12:5432/opencut'"
    exit 1
  fi
fi

ENVFILE="$(dirname "$0")/.env.local"
# Update DATABASE_URL in .env.local
sed -i "s|^DATABASE_URL=.*|DATABASE_URL=\"${DBURL}\"|" "$ENVFILE"
echo "DATABASE_URL updated"

# Run migration
cd "$(dirname "$0")"
bun run db:migrate
echo "Migration done"

# Cleanup sensitive temp files
rm -f /tmp/opencut_dburl.txt
ssh zeta@192.168.0.12 'rm -f /tmp/opencut_dburl.txt' 2>/dev/null || true

# Restart app
systemctl --user restart opencut-classic.service
sleep 3
curl -sI 127.0.0.1:5273/ | head -2
echo "Setup complete"
