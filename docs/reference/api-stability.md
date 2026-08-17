# API stability

Campsend separates machine-consumed JSON endpoints from browser pages and durable links.

## Versioned JSON API

JSON endpoints live under `/api/v1`. Within a version, changes are additive: existing fields keep their names, types, and meaning. A breaking request or response change requires a new version that runs alongside the old one while consumers migrate.

Version 1 currently contains:

| Method | Path | Purpose |
| --- | --- | --- |
| `POST` | `/api/v1/direct_uploads` | Creates an authenticated Active Storage upload grant. |
| `POST` | `/api/v1/google_drive_imports` | Queues authenticated Google Drive snapshot imports. |

Controlled failures return JSON in the form `{"error":"message"}` with an appropriate 4xx status. These endpoints are consumed by Campsend's own browser code; Campsend does not yet expose API-key authentication for third-party clients.

## Durable links

Delivery URLs under `/d/:public_id` and sign-in URLs under `/sign-in/:public_id` are unversioned public contracts. Campsend does not change or reuse a published identifier. New behavior must preserve previously issued links.

## Browser routes

Other server-rendered HTML routes are private application interfaces. They may change with the Campsend UI and are not part of the versioned JSON API.
