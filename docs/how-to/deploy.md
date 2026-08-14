# Deploying Campdoc

This guide deploys one Campdoc web host with Docker or Kamal. It uses SQLite on a persistent volume and either local or S3-compatible file storage.

## Preparing The Environment

Copy `.env.example` into your secret management system and set every required production value. The [configuration reference](../reference/configuration.md) lists each variable.

Generate a unique Rails master key for the installation. Do not commit secrets or a populated environment file.

## Choosing File Storage

For files on the persistent application volume, set:

```text
ACTIVE_STORAGE_SERVICE=local
```

For a private S3-compatible bucket, set:

```text
ACTIVE_STORAGE_SERVICE=s3
STORAGE_ENDPOINT=https://storage.example.com
STORAGE_REGION=us-east-1
STORAGE_BUCKET=campdoc
STORAGE_ACCESS_KEY_ID=...
STORAGE_SECRET_ACCESS_KEY=...
STORAGE_FORCE_PATH_STYLE=false
```

Cloudflare R2 uses region `auto` and path-style requests. If presigned upload URLs use a different origin from `STORAGE_ENDPOINT`, set `STORAGE_BROWSER_ORIGIN` to that origin.

Keep the bucket private. Give the credentials object read, write, and delete access for the Campdoc bucket, without account administration permissions.

Configure browser uploads on the bucket. For R2, replace the origin in this policy with your Campdoc origin:

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

## Configuring Email

Set `APP_HOST`, `MAIL_FROM`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, and `SMTP_PASSWORD`. Campdoc uses SMTP for sign-in and delivery links.

## Preparing SQLite

Mount a persistent volume at `/rails/storage`. This volume contains the application, cache, queue, and cable databases. Run one writable Campdoc host against it.

Back up every SQLite database with a SQLite-aware snapshot process. Test restores and monitor free disk space. Move to a server database before adding another application host.

## Deploying With Kamal

Replace the example host, registry, app host, mail settings, and storage settings in `config/deploy.yml`. Load secret values through `.kamal/secrets`, then run:

```sh
bin/kamal setup
```

Later releases can use:

```sh
bin/kamal deploy
```

The container entrypoint prepares the database before the Rails server starts.

## Verifying The Deployment

1. Open `/up` and confirm it returns HTTP 200.
2. Request a sign-in email and consume the link once.
3. Send and download a small file.
4. Confirm the sender dashboard records the events.
5. Confirm database and file backups include the persistent storage volume.

Changing `ACTIVE_STORAGE_SERVICE` does not move existing files. Read the [security and storage explanation](../explanation/security-model.md) before migrating objects.
