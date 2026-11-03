# Classroom Exchange

Classroom Exchange is a stock-trading game for a school class. Students earn virtual money for attendance and grades, then buy and sell shares in fictional companies. Teachers manage their classes and enter grades and attendance. Admins manage schools, years and stocks.

It's a Ruby on Rails app with server-rendered pages, Postgres and Redis.

## Start the app

You need Docker and nothing else.

```console
docker compose up
```

The first start builds the image and seeds the database, which takes a few minutes. Then open http://localhost:3000.

To use a different port, set `APP_PORT`, for example `APP_PORT=3100 docker compose up`.

## Demo logins

| Role    | Username | Password |
|---------|----------|----------|
| Student | Student  | password |
| Teacher | Teacher  | password |
| Admin   | Admin    | password |

## Run the tests

```console
docker compose run --rm test
```

## Run other commands

Run any Rails command inside the running app:

```console
docker compose exec app bin/rails console
```

## Background jobs

The `jobs` service runs the app's scheduled jobs, such as executing pending orders. It starts with `docker compose up`.

## Start again from scratch

This deletes the database and starts fresh:

```console
docker compose down -v
docker compose up
```

## Licence

MIT. See `LICENSE.md`.
