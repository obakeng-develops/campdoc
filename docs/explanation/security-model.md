# Delivery and storage security

Campsend separates application authorization from object storage. A recipient cannot derive a permanent bucket URL from a Campsend delivery link.

## Sign-in links

A sign-in email contains a public token ID and a random bearer token in the URL fragment. Fragments are not sent in the HTTP request. Browser JavaScript moves the bearer token into a CSRF-protected POST, removes the fragment from browser history, and exchanges it for a sender session.

Campsend stores a SHA-256 digest of the token. The link expires after 15 minutes and can be consumed once.

## Delivery links

Recipient links use the same fragment exchange pattern. A sender may choose a public delivery slug, but the slug only identifies the delivery and never grants access. Slugs are visible to recipients and must not contain secrets. A successful exchange stores a grant bound to the delivery's current access token in the recipient's encrypted browser session. The browser can keep up to ten delivery grants.

A signed-in user can also discover active deliveries addressed to their normalized account email in Shared with me. The matching account may open those deliveries without the bearer token. Recipients without accounts can continue using the complete delivery link, and a signed-in account with a different email gains no additional access.

Delivery links expire after 30 days. A sender can revoke one or rotate it by emailing a fresh token. Rotation invalidates browser grants created from the previous token. Rotation and email delivery happen in one locked database transaction, so an SMTP failure preserves the previous working link.

Published slugs cannot be changed, deleted, or reused. A sender can revoke recipient access while the durable path continues to resolve to the generic unavailable page.

Known expired and revoked deliveries return a generic unavailable page without exposing recipient details. Unknown delivery IDs continue to use the standard not-found response.

Private pages send `Cache-Control: private, no-store` and use a `no-referrer` policy. The unauthenticated confirmation page does not reveal the recipient email address.

Scheduled deliveries keep their public identifier but issue no access token until publication. Before publication, recipient routes return a generic not-yet-available page without sender, recipient, file, or schedule details. The database publication state controls access; delayed queue entries only wake the publication job.

Publication records `published_at`, issues the access token, and sends email while holding the delivery lock. Retries cannot publish a committed delivery twice. SMTP remains at least once: if the provider accepts an email and the process stops before the database commit, a retry may send a duplicate.

## File uploads

A sender session must be active before Campsend creates a direct-upload grant. Each new blob records its uploader, and a delivery rejects blobs owned by another sender. The application also checks the declared file count and total size before saving a delivery.

Direct uploads use short-lived signed storage requests. The bucket CORS policy should allow `PUT` from the Campsend origin and no broader browser access.

## File downloads

Campsend checks the sender or recipient session before every file request. After authorization it redirects to a five-minute Active Storage URL. The bucket remains private.

Files in Shared with me remain attached to the sender's delivery. They are not copied into the recipient's library or counted as recipient-owned storage.

Collections contain ordered files from one sender's My Files library. Composite database foreign keys prevent a collection or collection-backed delivery from crossing user ownership. Each collection update creates an immutable delivery revision, so recipients see the latest files at the same URL while senders retain earlier versions. Removing a collection leaves existing delivery revisions intact.

Deleting a delivery removes its recipient access and activity. A blob remains stored while it is kept in My Files or another delivery, and it is purged after its final attachment is removed.

Only Active Storage's web-safe image types can render inline for recipients. Other formats download as attachments or are rejected from recipient previews. This prevents an uploaded active document from running as Campsend content.

## Google Drive imports

Google authorization does not sign a user into Campsend. An active Campsend session opens Google Picker with the narrow `drive.file` scope, which grants access to files selected in Picker rather than the user's complete Drive.

Campsend receives selected file IDs and a short-lived access token. It encrypts the token before placing it in Solid Queue and does not store a refresh token. The import job asks Google for authoritative name, type, size, download permission, and checksum metadata. It constructs Drive API URLs itself and will not fetch a client-supplied URL.

Each import becomes a private snapshot in Campsend's Active Storage service. Later edits, deletion, or permission changes in Drive do not change a completed snapshot. The snapshot belongs to the importing user and follows the same My Files, delivery, and deletion rules as a browser upload.

The first version accepts binary Drive files. It rejects native Google Workspace documents, folders, shortcuts, blocked downloads, and files over 2 GB. Downloads stream through temporary disk, must match Google's declared size and checksum, and are attached only after storage upload succeeds. Failed imports purge their blob reservation.

## Storage lifecycle

Active Storage records the service used by each blob. Changing `ACTIVE_STORAGE_SERVICE` changes where new blobs are written; it does not move existing objects.

A storage migration needs three separate steps:

1. Copy every object to the new private service.
2. Verify object keys, sizes, and checksums.
3. Update each blob's `service_name` after its object has been verified.

Keep the old service available until every existing delivery has been tested against the new location.

## Operational boundary

The default production design uses one Rails host and SQLite databases on one persistent volume. SQLite does not provide a shared multi-host write boundary. Add a server database and shared object storage before running more than one application host.
