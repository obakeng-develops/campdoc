# Terminology

Some words mean something specific in Campsend. In a few places the code's name and the domain's name disagree, and that's where you'll lose time if nobody tells you first.

## Send and delivery

The Active Record class is `Send`, in `app/models/send.rb`. Everywhere else the concept is called a **delivery**: routes, mailers, jobs, associations, UI copy. There's no `Delivery` class. Don't add one.

The gap is bridged with `class_name:` and `foreign_key:`:

```ruby
# app/models/send_event.rb
belongs_to :delivery, class_name: "Send", foreign_key: :send_id, inverse_of: :send_events

# app/models/send.rb
has_many :delivery_revisions, -> { order(number: :asc) }, inverse_of: :delivery, dependent: :destroy
has_many :send_events, inverse_of: :delivery, dependent: :delete_all
```

So `send_event.delivery` returns a `Send`, and so does `DeliveryRevision#delivery`.

When you name something new, use `delivery`. Keep `Send` for the class itself. `send` is already a Ruby method name, which is part of why the domain word won everywhere else.

## Sender side and recipient side

There are two controller families, and they split by audience rather than by noun.

`SendsController` and `app/controllers/sends/*` are the sender's side. They live at `/sends`, need a session, and cover index, new, create and edit, plus `cancel`, `revoke_access` and `rotate_access`.

`DeliveriesController` and `app/controllers/deliveries/*` are the recipient's side. They live at `/d/:public_id`, need no account, and are guarded by the `DeliveryAccess` concern.

So "change the delivery page" is ambiguous until you know which side you're on. Sender work goes in `sends/`. Recipient work goes in `deliveries/`.

## Identifiers

**`public_id`**: random, from `has_secure_token`. Always present.

**`slug`**: optional, sender-chosen, lowercase and dashes (`SLUG_FORMAT`), excluded from `RESERVED_SLUGS`. Once it's published it can't change, and it's never deleted or reused.

**`delivery_identifier`**: `slug.presence || public_id`. Use this value in a URL. Look deliveries up with `Send.find_by_delivery_identifier!`, which takes either form.

**`access_token`**: the bearer secret. Never put it in a URL path, in JSON, or in tool output. Only its SHA-256 digest is stored, as `access_token_digest`.

A slug only identifies a delivery. It never grants access. See [the security model](../explanation/security-model.md).

## Revisions

Delivery files live on `DeliveryRevision`, not on the delivery itself. Revisions are append-only and numbered from 1. `Send#files` reads the latest one.

`Send#files=` raises `ActiveRecord::ReadOnlyRecord` once the record is persisted. To replace a file, call `replace_file!`. It appends a new revision instead of changing the current one.

## Three kinds of status

`Send#status` is the furthest event reached: `downloaded`, then `opened`, then `sent`, or `nil`.

`Send#access_state` is one of `canceled`, `revoked`, `expired` or `active`.

`Send#display_status` is what the UI shows. It folds in `scheduled`, `sending` and `failed`.

Read `display_status` when you're rendering. Don't recompute any of the three inline.

## Other terms

**Collection**: a named, reusable set of files. A delivery can follow a collection through `Send#collection`. Its files then track the collection via `revise_from_collection!`, and `replace_file!` refuses to run.

**Shared with me**: `ReceivedSendsController` at `/shared`. Deliveries addressed to the signed-in account's normalized email.

**Policy**: `Campsend.policy`, the extension seam. See [practices](practices.md).

**Wide event**: the one structured log line per request. See [practices](practices.md).
