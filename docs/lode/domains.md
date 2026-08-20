# Domains

What the parts of Campsend are for. Read [terminology](terminology.md) first: it explains why `Send` is the class and "delivery" is the word.

## Delivery, the spine

Everything else exists to serve a delivery. A delivery is content plus controlled access, and the two are separate on purpose.

`Send` holds the delivery. `DeliveryRevision` holds its files, so editing a published delivery makes a new revision rather than changing what a recipient already has a link to. `SendEvent` records what happened to it.

Access is a bearer token in the URL fragment, exchanged through a CSRF-protected POST, with the resulting grant in the encrypted session. The fragment never reaches a server, so the token stays out of access logs, proxies and referrers. Anything that moves it into a path or a query undoes that.

The `available` scope is the whole availability rule in one place: published, not canceled, not revoked, not expired, and still holding a token digest. Read it before adding a sixth condition somewhere else.

## Recipient access

`sign_ins` and `deliveries`, plus the `DeliveryAccess` concern.

This is the only surface reachable without an account, and the only one most recipients ever see. It has no navigation and belongs to whoever received the delivery rather than to whichever account is looking, which is why delivery pages never render inside the application shell.

## Library

`Collection`, `CollectionFile`, `GoogleDriveImport`, and the `files` and `collections` controllers.

Files a sender already uploaded, ready to send again without uploading them twice. The library is why a delivery references blobs rather than owning them.

## Identity

`User` and `LoginToken`. Sign-in is a single-use link, so there is no password to store, reset or leak.

`User#reserve_blob!` deserves naming here even though it is not obviously identity. Every upload passes through it, and it is where storage limits are enforced and where the storage service is chosen. It is the choke point, and code that creates blobs around it bypasses both.

## Policy, the extension point

`Campsend.policy` is how a distribution changes what a plan allows without changing this code.

Core never names a plan and never asks who is paying. It asks the policy whether an upload is admitted, whether a delivery is admitted, what usage to show, and which storage service to use. The open distribution ships a permissive default where everything is allowed.

A distribution that sells plans subclasses it. That is the entire seam, and keeping it that small is what makes the two distributions the same application. See [practices](practices.md).

## Two controller families

Controllers split by audience rather than by model. `sends` is the sender composing and managing. `deliveries` is the recipient receiving. They touch the same records and answer to different people, and merging them would mean one controller deciding, per action, which of two audiences it is talking to.
