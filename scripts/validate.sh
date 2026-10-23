#!/bin/sh
set -eu

APP_URL="${APP_URL:?APP_URL obligatoire}"
RETRIES="${RETRIES:-20}"
SLEEP_SECONDS="${SLEEP_SECONDS:-10}"

echo "==> Validation de ${APP_URL}"
i=1
while [ "$i" -le "$RETRIES" ]; do
  echo "Tentative ${i}/${RETRIES}..."
  CODE="$(curl -sS -o /tmp/paymybuddy_body.txt -w "%{http_code}" "$APP_URL" || echo "000")"
  case "$CODE" in
    200|301|302)
      echo "OK: application joignable (HTTP ${CODE})"
      head -c 200 /tmp/paymybuddy_body.txt || true
      echo
      exit 0
      ;;
  esac
  i=$((i + 1))
  sleep "$SLEEP_SECONDS"
done

echo "ERROR: validation échouée"
exit 1
