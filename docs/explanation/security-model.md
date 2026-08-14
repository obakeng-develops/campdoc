# Private Delivery And Storage Security

Campdoc separates application authorization from object storage. A recipient cannot derive a permanent bucket URL from a Campdoc delivery link.

## Sign-In Links

A sign-in email contains a public token ID and a random bearer token in the URL fragment. Fragments are not sent in the HTTP request. Browser JavaScript moves the bearer token into a CSRF-protected POST, removes the fragment from browser history, and exchanges it for a sender session.

Campdoc stores a SHA-256 digest of the token. The link expires after 15 minutes and can be consumed once.

## Delivery Links

Recipient links use the same fragment exchange pattern. A successful exchange stores the delivery public ID in the recipient's encrypted browser session. The browser can keep up to ten delivery grants.

A signed-in user can also discover active deliveries addressed to their normalized account email in Shared with me. The matching account may open those deliveries without the bearer token. Recipients without accounts can continue using the private link, and a signed-in account with a different email gains no additional access.

Delivery links expire after 30 days. A sender can revoke one or rotate it by emailing a fresh token. Rotation and email delivery happen in one locked database transaction, so an SMTP failure preserves the previous working link.

Private pages send `Cache-Control: private, no-store` and use a `no-referrer` policy. The unauthenticated confirmation page does not reveal the recipient email address.

## File Uploads

A sender session must be active before Campdoc creates a direct-upload grant. Each new blob records its uploader, and a delivery rejects blobs owned by another sender. The application also checks the declared file count and total size before saving a delivery.

Direct uploads use short-lived signed storage requests. The bucket CORS policy should allow `PUT` from the Campdoc origin and no broader browser access.

## File Downloads

Campdoc checks the sender or recipient session before every file request. After authorization it redirects to a five-minute Active Storage URL. The bucket remains private.

Files in Shared with me remain attached to the sender's delivery. They are not copied into the recipient's library or counted as recipient-owned storage.

Only Active Storage's web-safe image types can render inline for recipients. Other formats download as attachments or are rejected from recipient previews. This prevents an uploaded active document from running as Campdoc content.

## Storage Lifecycle

Active Storage records the service used by each blob. Changing `ACTIVE_STORAGE_SERVICE` changes where new blobs are written; it does not move existing objects.

A storage migration needs three separate steps:

1. Copy every object to the new private service.
2. Verify object keys, sizes, and checksums.
3. Update each blob's `service_name` after its object has been verified.

Keep the old service available until every existing delivery has been tested against the new location.

## Operational Boundary

The default production design uses one Rails host and SQLite databases on one persistent volume. SQLite does not provide a shared multi-host write boundary. Add a server database and shared object storage before running more than one application host.
