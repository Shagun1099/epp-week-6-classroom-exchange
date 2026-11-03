#!/usr/bin/env bash
# Deploy Classroom Exchange as the hosted copy for testers, on a Linux server.
# Tested target: Ubuntu on AWS. See deployment.md.
#
#   ./scripts/deploy.sh                  first deploy, or redeploy after git pull
#   ./scripts/deploy.sh --domain NAME    use your own domain (first deploy only)
#   ./scripts/deploy.sh --reset          start again with fresh seed data
#
# Settings live in ~/classroom-exchange.env, outside the repository.
# Set CX_ENV_FILE to use a different path.

set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${CX_ENV_FILE:-$HOME/classroom-exchange.env}"
DOMAIN=""
RESET=false

usage() {
  awk 'NR > 1 && /^#/ { sub(/^# ?/, ""); print; next } NR > 1 { exit }' "$0"
}

while [ $# -gt 0 ]; do
  case "$1" in
    --domain) DOMAIN="${2:?--domain needs a value}"; shift 2 ;;
    --reset) RESET=true; shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
done

say() { printf '\n==> %s\n' "$1"; }

# 1. Docker
if ! command -v docker >/dev/null 2>&1; then
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Docker isn't installed, and this script can only install it on Ubuntu or Debian." >&2
    exit 1
  fi
  say "Installing Docker"
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker "$USER"
  echo "Added $USER to the docker group. It takes effect from your next login."
fi

DOCKER=(docker)
if ! docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
fi

# 2. Settings file, created once
if [ ! -f "$ENV_FILE" ]; then
  say "Creating $ENV_FILE"

  if [ -z "$DOMAIN" ]; then
    public_ip="$(curl -fsS --max-time 10 https://checkip.amazonaws.com || curl -fsS --max-time 10 https://ifconfig.me)"
    public_ip="$(echo "$public_ip" | tr -d '[:space:]')"
    DOMAIN="${public_ip//./-}.sslip.io"
    echo "No domain given, so using $DOMAIN (sslip.io points it at this server's IP)."
  fi

  umask 077
  cat >"$ENV_FILE" <<SETTINGS
COMPOSE_PROJECT_NAME=classroom-exchange
DOMAIN=$DOMAIN
SETTINGS
elif [ -n "$DOMAIN" ]; then
  echo "Note: $ENV_FILE already exists, so --domain is ignored. Edit the file to change it." >&2
fi

# Prints a setting's value, or nothing if the file doesn't set it.
setting() { { grep -E "^$1=" "$ENV_FILE" || true; } | head -n1 | cut -d= -f2- | tr -d '"'; }
SITE_DOMAIN="$(setting DOMAIN)"
PROJECT="$(setting COMPOSE_PROJECT_NAME)"
HTTPS_PORT="$(setting PROXY_HTTPS_PORT)"
SITE_URL="https://$SITE_DOMAIN${HTTPS_PORT:+:$HTTPS_PORT}"

COMPOSE=("${DOCKER[@]}" compose --env-file "$ENV_FILE" -f docker-compose.yml -f docker-compose.hosted.yml)

# 3. Start
if [ "$RESET" = true ]; then
  say "Stopping everything and deleting the database, so the seed data is restored on start"
  "${COMPOSE[@]}" down
  "${DOCKER[@]}" volume rm "${PROJECT}_postgres" >/dev/null 2>&1 || true
fi

say "Building and starting (the first time takes several minutes)"
"${COMPOSE[@]}" up -d --build

# 4. Check it answers over HTTPS with the login page.
say "Waiting for $SITE_URL"
curl_opts=(-fsS --max-time 5)
if [ "$SITE_DOMAIN" = "localhost" ]; then
  curl_opts+=(-k)
fi
for _ in $(seq 1 120); do
  if curl "${curl_opts[@]}" "$SITE_URL/users/sign_in" 2>/dev/null | grep -q "Classroom Exchange"; then
    cat <<DONE

Classroom Exchange is up.

  Site:            $SITE_URL
  Admin login:     Admin / password
  Student login:   Student / password
  Test settings:   in the admin menu, under Testing

All data is made up.
DONE
    exit 0
  fi
  sleep 5
done

cat >&2 <<HELP

The site didn't answer within 10 minutes. Check that:
  - ports 80 and 443 are open to the internet
  - $SITE_DOMAIN points at this server
  - the server has at least 2 GB of memory
Then read the logs:
  ${COMPOSE[*]} logs proxy app
HELP
exit 1
