# Deploying the hosted copy

`scripts/deploy.sh` runs Classroom Exchange as a hosted copy on a Linux server, for testers. Tested target: Ubuntu. It works on any Ubuntu or Debian server with a public IP.

It uses the same code and containers as local development, with these differences, set in `docker-compose.hosted.yml`:

- Caddy serves the site over HTTPS, and tells search engines not to index it. `robots.txt` blocks them too.
- Only Caddy is reachable from outside. The app itself has no public port.
- Errors show a plain error page, not the developer's error page, and the pages don't name their templates.
- The admin **Test settings** page is switched on.
- Everything restarts on its own after a server reboot.
- The demo logins are the same as in the README. All data is made up.

## The server

- Ubuntu, with at least 2 GB of memory (on AWS, a `t3.small`). The first build needs most of it.
- At least 20 GB of disk. AWS gives Ubuntu 8 GB by default, which isn't enough: the app's images take about 4 GB, and the build needs about twice that while it runs.
- Ports 80 and 443 open to everyone, and 22 open for SSH. Don't open 3000.
- A domain is optional. Without one, the site gets an address like `3-98-12-45.sslip.io`. It points at the server's IP and gets a real HTTPS certificate with no DNS setup.

## First deployment

1. Connect with agent forwarding, so the server can clone the repository using your own GitHub key, without storing anything on the server:

   ```bash
   ssh -A ubuntu@<server address>
   ```

2. Clone the repository and run the script:

   ```bash
   git clone git@github.com:Prepr/epp-week-6-classroom-exchange.git
   cd epp-week-6-classroom-exchange
   ./scripts/deploy.sh
   ```

   To use your own domain, point its DNS at the server first, then run `./scripts/deploy.sh --domain test.example.com`.

The script installs Docker if it's missing, creates `~/classroom-exchange.env` with the site's settings, builds and starts everything, waits until the login page loads over HTTPS, then prints the site address and logins. The first run takes about ten minutes.

## Everyday use

Run these from the repository folder on the server.

| To | Run |
|---|---|
| Redeploy after pulling new code | `git pull && ./scripts/deploy.sh` |
| Restore the seed data | `./scripts/deploy.sh --reset` |
| Read the logs | `docker compose --env-file ~/classroom-exchange.env -f docker-compose.yml -f docker-compose.hosted.yml logs -f app` (straight after the first deployment, start it with `sudo`, or log in again) |

The data is kept between restarts. Use `--reset` if testers fill the site with junk: it deletes the database, and the seed data is loaded again on start.
