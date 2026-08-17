# Configuration reference

Campsend reads production configuration from environment variables. Production boot stops when a required setting is missing.

## Application

| Variable | Required | Description |
| --- | --- | --- |
| `APP_HOST` | Yes | Public hostname used in links and host authorization. Do not include the protocol. |
| `CAMPSEND_MANAGED` | No | Enables public marketing pages and managed plan limits when `true`. Defaults to `false`. |
| `ACTIVE_STORAGE_SERVICE` | Yes | `local` or `s3`. |
| `RAILS_MASTER_KEY` | For encrypted credentials | Decrypts `config/credentials.yml.enc`. |
| `RAILS_LOG_LEVEL` | No | Rails log level. Defaults to `info`. |
| `SOLID_QUEUE_IN_PUMA` | No | Runs Solid Queue inside Puma when set to `true`. Suitable for one host. |
| `JOB_CONCURRENCY` | No | Number of Solid Queue worker processes. Defaults to `1`. |
| `WEB_CONCURRENCY` | No | Number of Puma processes. Defaults to `1`. |

## Email

| Variable | Required | Description |
| --- | --- | --- |
| `MAIL_FROM` | Yes | Sender shown on Campsend email. |
| `SMTP_ADDRESS` | Yes | SMTP server hostname. |
| `SMTP_PORT` | No | SMTP server port. Defaults to `587`. |
| `SMTP_USERNAME` | Yes | SMTP authentication username. |
| `SMTP_PASSWORD` | Yes | SMTP authentication password. |

## S3-compatible storage

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

## Google Drive imports

Google Drive imports are disabled unless all three values are set. These values are sent to the browser and must be restricted in Google Cloud rather than treated as server secrets.

| Variable | Required | Description |
| --- | --- | --- |
| `GOOGLE_DRIVE_CLIENT_ID` | To enable Drive | OAuth web client ID with the Campsend origin listed as an authorized JavaScript origin. |
| `GOOGLE_DRIVE_API_KEY` | To enable Drive | Browser API key restricted to the Campsend origin and Google Picker API. |
| `GOOGLE_DRIVE_APP_ID` | To enable Drive | Numeric Google Cloud project number used as the Picker app ID. |

Campsend requests the non-sensitive `drive.file` scope. It can read files the user selects in Google Picker, but it cannot browse the account outside Picker. Imports support binary Drive files up to 2 GB. Google Docs, Sheets, Slides, folders, and shortcuts are not supported.

## Security lifetimes and limits

| Setting | Value |
| --- | --- |
| Sign-in link lifetime | 15 minutes, single use |
| Sender session lifetime | 30 days |
| Delivery link lifetime | 30 days |
| Signed storage URL lifetime | 5 minutes |
| Maximum files per delivery | 20 |
| Maximum delivery size | 2 GB |
| Stored recipient access grants per browser session | 10 |

## Managed plans

Managed accounts default to the Free plan with 2 GB of storage and five deliveries per calendar month. Pro accounts have 250 GB of storage and unlimited deliveries. Storage includes each blob uploaded by the account once, even when the file appears in My Files and several deliveries.

Billing is not connected yet. An operator can grant Pro access from the Rails console:

```ruby
User.find_by!(email_address: "person@example.com").update!(plan: "pro")
```

Self-hosted installations ignore managed plan limits.

## Scheduled work

Production runs `SecurityCleanupJob` every day at 3am. It removes expired login tokens, old Drive import statuses, and unattached uploads older than one day. Solid Queue removes finished jobs every hour at minute 12.

Scheduled deliveries use Solid Queue delayed jobs. Keep a queue worker running whenever the web process is running; publication time is stored in UTC and checked again from the primary database when each job starts.

## Wide events

Campsend emits one JSON wide event at the end of each application request and background job. Request events include the request ID, route, status, duration, authenticated user ID and plan, plus delivery or upload context added during processing. Job events include the job ID, class, queue, outcome, duration, and relevant domain IDs. Health checks and static assets are excluded.

The events are written to standard output through the Rails logger. They contain user and record IDs but exclude email addresses, access tokens, file names, and exception messages. `KAMAL_VERSION`, when present, is recorded as `service_version` so incidents can be grouped by deployment.
