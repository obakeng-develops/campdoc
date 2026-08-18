# Load test Campsend locally

The Locust harness exercises authenticated reads, concurrent delivery creation, recipient access, and downloads. It refuses non-loopback hosts.

Use development with local Disk storage and file mail delivery. Never load production data or credentials.

## Prepare disposable users

```sh
COUNT=25 bin/rails runner script/prepare_load_test.rb
```

This writes one-time credentials to `tmp/locust_users.json`. Run it again before each test because sign-in links are single-use.

## Run a baseline

Start Campsend, then run:

```sh
locust -f locustfile.py --host http://localhost:3000 --headless -u 5 -r 1 -t 1m
```

## Stress SQLite

Prepare at least as many users as Locust will spawn:

```sh
COUNT=50 bin/rails runner script/prepare_load_test.rb
CAMPSEND_LOAD_MAX_DELIVERIES=3 locust -f locustfile.py --host http://localhost:3000 --headless -u 50 -r 5 -t 5m
```

Watch Rails logs for `SQLite3::BusyException`, failed jobs, request errors, and slow delivery creation. Compare p50, p95, p99, failures, CPU, memory, and database growth between runs.

The application rate limit allows 20 deliveries per user per hour. Keep `CAMPSEND_LOAD_MAX_DELIVERIES` below that limit unless rate-limit behavior is the subject of the test.
