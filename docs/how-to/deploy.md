# Deploying Campsend

This guide deploys one Campsend web host with Docker or Kamal. It uses SQLite on a persistent volume and either local or S3-compatible file storage.

## Preparing the environment

Copy `.env.example` into your secret management system and set every required production value. The [configuration reference](../reference/configuration.md) lists each variable.

Generate a unique Rails master key for the installation. Do not commit secrets or a populated environment file.

Campsend defaults to self-hosted mode, where the root page opens sign-in and managed storage and delivery limits are disabled.

## Choosing file storage

For files on the persistent application volume, set:

```text
ACTIVE_STORAGE_SERVICE=local
```

For a private S3-compatible bucket, set:

```text
ACTIVE_STORAGE_SERVICE=s3
STORAGE_ENDPOINT=https://storage.example.com
STORAGE_REGION=us-east-1
STORAGE_BUCKET=campsend
STORAGE_ACCESS_KEY_ID=...
STORAGE_SECRET_ACCESS_KEY=...
STORAGE_FORCE_PATH_STYLE=false
```

Cloudflare R2 uses region `auto` and path-style requests. If presigned upload URLs use a different origin from `STORAGE_ENDPOINT`, set `STORAGE_BROWSER_ORIGIN` to that origin.

Keep the bucket private. Give the credentials object read, write, and delete access for the Campsend bucket, without account administration permissions.

Configure browser uploads on the bucket. For R2, replace the origin in this policy with your Campsend origin:

```json
[
  {
    "AllowedOrigins": ["https://campsend.example.com"],
    "AllowedMethods": ["PUT"],
    "AllowedHeaders": ["Content-Type", "Content-MD5", "Content-Disposition"],
    "ExposeHeaders": ["ETag"],
    "MaxAgeSeconds": 3600
  }
]
```

## Configuring email

Set `APP_HOST`, `MAIL_FROM`, `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, and `SMTP_PASSWORD`. Campsend uses SMTP for sign-in and delivery links.

## Enabling Google Drive imports

Google Drive support is optional. Leave its variables blank to keep it disabled.

To enable it:

1. Create or select a Google Cloud project.
2. Enable the Google Picker API and Google Drive API.
3. Configure the OAuth consent screen with the `https://www.googleapis.com/auth/drive.file` scope.
4. Create an OAuth web client and add the complete Campsend origin, such as `https://campsend.example.com`, under authorized JavaScript origins.
5. Create an API key. Restrict it to the Campsend browser origin and Google Picker API.
6. Set `GOOGLE_DRIVE_CLIENT_ID`, `GOOGLE_DRIVE_API_KEY`, and `GOOGLE_DRIVE_APP_ID`. The app ID is the numeric project number.

The client ID, API key, and app ID are browser-public configuration. Do not add a Google client secret. Campsend uses a short-lived browser token for each import and does not retain Google refresh tokens.

## Preparing SQLite

Mount a persistent volume at `/rails/storage`. This volume contains the application, cache, queue, and cable databases. Run one writable Campsend host against it.

Keep Solid Queue running so scheduled deliveries publish on time. The default deployment runs it inside Puma with `SOLID_QUEUE_IN_PUMA=true`; split it into a dedicated job process before adding more web hosts.

Back up every SQLite database with a SQLite-aware snapshot process. Test restores and monitor free disk space. Move to a server database before adding another application host.

## Deploying with Kamal

Replace the example host, registry, app host, mail settings, and storage settings in `config/deploy.yml`. Load secret values through `.kamal/secrets`, then run:

```sh
bin/kamal setup
```

Later releases can use:

```sh
bin/kamal deploy
```

The container entrypoint prepares the database before the Rails server starts.

## Verifying the deployment

1. Open `/up` and confirm it returns HTTP 200.
2. Request a sign-in email and consume the link once.
3. Send a small file and confirm it appears in My Files.
4. Sign in as the recipient and confirm the delivery appears in Shared with me.
5. Download the file and confirm the **Sent** page shows the delivery events.
6. Confirm database and file backups include the persistent storage volume.
7. If Google Drive is enabled, import a small PDF into My Files and confirm it remains downloadable after changing the source file in Drive.

Changing `ACTIVE_STORAGE_SERVICE` does not move existing files. Read the [security and storage explanation](../explanation/security-model.md) before migrating objects.
