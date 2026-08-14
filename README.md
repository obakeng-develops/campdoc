# Campdoc

Campdoc is a private, file-first delivery tool. A sender adds files, a recipient, and a note. The recipient gets a private link, and the sender can see when the delivery is opened or downloaded.

## Local setup

Campdoc uses Ruby 3.3.4, Rails 8.1, SQLite, and local disk storage in development.

```sh
bin/setup
bin/dev
```

Development emails are written to `tmp/mails`. Open the latest file there to get the sign-in or delivery link.

Run the checks with:

```sh
bin/rails test
bin/rubocop
bin/brakeman --no-pager
```

## Storage

Campdoc uses Active Storage. Development and test use local disk. Production supports local disk and private S3-compatible services such as Cloudflare R2, AWS S3, MinIO, Backblaze B2, and Wasabi.

Choose a service explicitly:

```text
ACTIVE_STORAGE_SERVICE=local
# or
ACTIVE_STORAGE_SERVICE=s3
```

For S3-compatible storage, set `STORAGE_ENDPOINT`, `STORAGE_REGION`, `STORAGE_BUCKET`, `STORAGE_ACCESS_KEY_ID`, `STORAGE_SECRET_ACCESS_KEY`, and `STORAGE_FORCE_PATH_STYLE`. If presigned upload URLs use a different origin than the endpoint, allow it with `STORAGE_BROWSER_ORIGIN`. For R2, use the account S3 endpoint, region `auto`, and path-style requests.

Keep the bucket private. Credentials need object read, write, and delete access only for the selected bucket. Do not grant account-wide administration or public object access.

Direct browser uploads need this R2 CORS policy. Replace the origin with the production app origin.

```json
[
  {
    "AllowedOrigins": ["https://campdoc.example.com"],
    "AllowedMethods": ["PUT"],
    "AllowedHeaders": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

Downloads remain private. Campdoc authorizes each request and issues a five-minute storage URL.

Changing `ACTIVE_STORAGE_SERVICE` does not move existing files. Active Storage records the service used by each blob. Copy and verify objects before updating existing `service_name` values.

## Production email

Set `APP_HOST`, `MAIL_FROM`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, and `SMTP_PASSWORD`. Passwordless sign-in links expire after 15 minutes and work once.

## Production SQLite

The default production setup uses SQLite for the application, cache, queue, and cable databases. Run one writable Campdoc host against one persistent volume. Do not deploy multiple hosts with separate SQLite volumes.

Back up every SQLite database in `storage/` with a SQLite-aware snapshot process. Test restores, monitor free disk space, and move to a server database before horizontal scaling.

## Private links

Delivery links expire after 30 days. Senders can revoke a link or email a fresh one. Private pages use `no-store` caching and files remain behind Campdoc authorization.

## Open source

Campdoc is available under the MIT License. See `SECURITY.md` for private vulnerability reporting. Copy `.env.example` for the supported environment settings, and generate unique Rails secrets for every installation.
