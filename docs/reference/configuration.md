# Configuration Reference

Campdoc reads production configuration from environment variables. Production boot stops when a required setting is missing.

## Application

| Variable | Required | Description |
| --- | --- | --- |
| `APP_HOST` | Yes | Public hostname used in links and host authorization. Do not include the protocol. |
| `CAMPDOC_MANAGED` | No | Shows the public landing and pricing pages when `true`. Defaults to `false`. |
| `ACTIVE_STORAGE_SERVICE` | Yes | `local` or `s3`. |
| `RAILS_MASTER_KEY` | For encrypted credentials | Decrypts `config/credentials.yml.enc`. |
| `RAILS_LOG_LEVEL` | No | Rails log level. Defaults to `info`. |
| `SOLID_QUEUE_IN_PUMA` | No | Runs Solid Queue inside Puma when set to `true`. Suitable for one host. |
| `JOB_CONCURRENCY` | No | Number of Solid Queue worker processes. Defaults to `1`. |
| `WEB_CONCURRENCY` | No | Number of Puma processes. Defaults to `1`. |

## Email

| Variable | Required | Description |
| --- | --- | --- |
| `MAIL_FROM` | Yes | Sender shown on Campdoc email. |
| `SMTP_ADDRESS` | Yes | SMTP server hostname. |
| `SMTP_PORT` | No | SMTP server port. Defaults to `587`. |
| `SMTP_USERNAME` | Yes | SMTP authentication username. |
| `SMTP_PASSWORD` | Yes | SMTP authentication password. |

## S3-Compatible Storage

These settings are required when `ACTIVE_STORAGE_SERVICE=s3`.

| Variable | Required | Description |
| --- | --- | --- |
| `STORAGE_ENDPOINT` | Yes | S3-compatible API origin. |
| `STORAGE_REGION` | No | Bucket region. Defaults to `us-east-1`; use `auto` for R2. |
| `STORAGE_BUCKET` | Yes | Private bucket name. |
| `STORAGE_ACCESS_KEY_ID` | Yes | Bucket access key. |
| `STORAGE_SECRET_ACCESS_KEY` | Yes | Bucket secret key. |
| `STORAGE_FORCE_PATH_STYLE` | No | Uses path-style URLs when `true`. Defaults to `false`. |
| `STORAGE_BROWSER_ORIGIN` | No | Additional CSP origin when presigned browser-upload URLs use a different origin from `STORAGE_ENDPOINT`. |

## Security Lifetimes And Limits

| Setting | Value |
| --- | --- |
| Sign-in link lifetime | 15 minutes, single use |
| Sender session lifetime | 30 days |
| Delivery link lifetime | 30 days |
| Signed storage URL lifetime | 5 minutes |
| Maximum files per delivery | 20 |
| Maximum delivery size | 2 GB |
| Stored recipient access grants per browser session | 10 |

## Scheduled Work

Production runs `SecurityCleanupJob` every day at 3am. It removes expired login tokens and unattached uploads older than one day. Solid Queue removes finished jobs every hour at minute 12.
