# Running Campdoc Locally

This tutorial gets Campdoc running and walks through one private file delivery.

## Before You Start

You'll need Ruby 3.3.4, SQLite 3, and libvips.

## Setting Up The Application

Run the setup script from the repository root:

```sh
bin/setup
```

This installs the gems and prepares the local SQLite databases.

Start the development server:

```sh
bin/dev
```

Open [http://localhost:3000](http://localhost:3000).

## Sending A File

1. Enter your email address on the sign-in page.
2. Open the sign-in email written to `tmp/mails`.
3. Follow the private link in that email.
4. Select a file, enter a recipient email and note, then send it.
5. Open the delivery email in `tmp/mails` and follow its private link.

The uploaded file now appears in My Files, where you can download it or use it in another Send. Sent records when the delivery is sent, opened, and downloaded.

## Receiving A File

Sign out, then request a sign-in link for the recipient email used above. After signing in, open Shared with me. The active delivery appears there without requiring the original bearer link.

The delivery still expires after 30 days and disappears if the sender revokes it. Shared files remain owned by the sender and are not copied into the recipient's My Files library.

## Running The Tests

Run the test suite:

```sh
bin/rails test
```

You now have a working local Campdoc installation. Use the [deployment guide](../how-to/deploy.md) when you're ready to run it in production.
