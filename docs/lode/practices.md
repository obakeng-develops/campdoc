# Practices

How Campsend is built, and which choices look like oversights but aren't.

## Shipping two distributions

Campsend ships from two repositories.

**Core** is this repo: the public application, self-hostable.

**Managed** is private. It mounts this repo as a `core/` submodule and adds proprietary hosting behavior in a Rails engine.

Behavior that both distributions need lands here first. Managed then adopts it by bumping the submodule pin.

Managed never patches files under `core/`. So if you're working in managed and you want to edit something in `core/`, stop. That diff gets discarded on the next `git submodule update`, and it never reaches a self-hoster. Open a PR here instead.

## Extending through Campsend.policy

`lib/campsend/policy.rb` is the only sanctioned extension point. Every method here is a no-op or a neutral default, and managed subclasses it.

```ruby
def admit_delivery(user:)
  yield          # core admits everything
end
```

Core calls `Campsend.policy.admit_delivery(user:) { ... }` and stays ignorant of plans, quotas and billing. So core carries no `if managed?`, no plan names, no price checks, no engine constants.

When core needs a new extension point, add a neutral method to `Policy` and call it. Name the branch after the thing it opens up, as in `feat/storage-service-policy` and `feat/storage-key-prefix-policy`.

A policy that refuses raises `Campsend::Policy::Denied`. It carries a `message` for the user and an `outcome` for machines. Callers rescue it, add `outcome` to the wide event, then render the message. `Api::V1::DirectUploadsController#create` is the reference.

## Emitting one wide event per request

Observability here is a single structured line per request, not scattered logging. `WideEvent` is a `CurrentAttributes` store. Middleware starts it and emits it, and handlers add fields along the way.

The reason is triage. One event per unit of work means one row describes what the system did: who asked, what it decided, what it called, what came back, and how long it took. Nobody reconstructs a story from five lines that happen to share a request id.

That row is also the handover. Someone who has never read this code, or a model handed the logs, should be able to say what happened without opening a file. Write fields that name the operation rather than the code path, and include the identifiers that let a reader follow the story outward: the user, and any id a third party will know it by too. A field that only makes sense to whoever wrote the line above it has missed the point.

Scattered logging pushes that work onto whoever is debugging at the time. A wide event does it once, while the author still knows what matters.

```ruby
WideEvent.add(delivery_id: @send.id, delivery_operation: "created", file_count: blobs.size, first_delivery:)
```

Don't add `Rails.logger.info` to a request path. Add fields to the wide event instead.

Field names follow `<noun>_<verb-or-noun>`: `delivery_operation`, `upload_operation`, `onboarding_event`. Use `outcome` for a refusal, and `error` with `exception_type` on a failure. `emit` compacts nils, so passing a nil field is how you leave one out conditionally.

## Running the tests

Minitest, no RSpec. `bin/ci` runs the suite through `ActiveSupport::ContinuousIntegration`, configured in `config/ci.rb`. Run it before you open a PR.

Managed's `bin/ci` runs in two phases. First it runs this repo's full suite against `core/Gemfile` with the engine excluded. Then it migrates and runs the engine suite with the engine loaded.

🚨 **NB**: core has to pass on its own Gemfile, so core can never depend on a gem that only managed installs. Managed declares its gems in `Gemfile.managed`, picked up by the `eval_gemfile ENV["CAMPSEND_EXTENSIONS_GEMFILE"]` line at the top of the Gemfile.

## Landing changes

Branch, PR, merge commit. Prefixes in use: `feat/`, `fix/`, `chore/`, `refactor/`, `copy/` and `docs/`. The history is merge commits (`Merge pull request #NN from ...`), not squashes.

## Leaving the deliberate compromises alone

Each of these is a decision. They look like bugs or unfinished work, so ask before you change one.

**`Send` isn't renamed to `Delivery`.** The class name appears in migrations and in every `send_id` foreign key, so renaming it costs a data migration and buys nothing. The domain word is handled with `class_name:` instead. See [terminology](terminology.md).

**There are no passwords.** Auth is magic-link only: `LoginToken`, 15 minutes, single use, SHA-256 digest. `bcrypt` is commented out in the Gemfile on purpose. There's no password reset flow waiting to be written.

**Published delivery files can't change.** `Send#files=` raises `ActiveRecord::ReadOnlyRecord` once the record is persisted, and revisions are append-only. That's what makes a delivery link a stable historical record.

**Published slugs can't be deleted.** `retain_published_slug` adds an error and calls `throw :abort` in `before_destroy`. A sender revokes access instead, and the path keeps resolving to a generic unavailable page.

**Email subaddressing gets stripped.** `User#email_address` and `Send#recipient_email` normalize with `.sub(/\+[^@]+/, "")`, so `sam+tag@example.com` becomes `sam@example.com`. That stops one mailbox opening many accounts, and it keeps the Shared with me recipient match working. It isn't retroactive, so rows written before it landed keep their `+tag`.

**SQLite with the Solid\* stack.** `solid_queue`, `solid_cache` & `solid_cable` on SQLite is the intended production posture, not a placeholder for Postgres and Redis.

**Secrets travel in URL fragments.** Sign-in and delivery links put the bearer token after `#`, so it never reaches the server in a request line. JavaScript then exchanges it through a CSRF-protected POST. Moving a token into a query parameter would be a regression. See [the security model](../explanation/security-model.md).

**`/api/v1` exists for Campsend's own browser code.** There's no third-party API-key auth today, and [api-stability](../reference/api-stability.md) says so. If that changes, and an MCP server or any other machine client would change it, update that doc in the same PR.

## Splitting the docs from this lode

Docs under `docs/` follow Diátaxis: `tutorials/`, `how-to/`, `reference/` and `explanation/`. They're written for people using and operating Campsend.

This lode is for whoever is working on Campsend, agent or human. Where the two overlap, the lode links to the doc instead of restating it. That way there's one source of truth and nothing to keep in sync.
