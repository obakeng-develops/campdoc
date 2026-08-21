# Running Campsend locally

This tutorial gets Campsend running and walks through one file delivery.

## Before you start

You'll need Ruby 3.3.4 and SQLite 3.

## Setting up the application

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

## Sending a file

1. Enter your email address on the sign-in page.
2. Open the sign-in email written to `tmp/mails`.
3. Follow the sign-in link in that email.
4. Select a file, enter a recipient email and note, then send it.
5. Open the delivery email in `tmp/mails` and follow its delivery link.

The uploaded file now appears in **My Files**, where you can download it or use it in another delivery. The **Sent** page shows when the delivery was sent, first opened, and first downloaded.

## Receiving a file

Sign out, then request a sign-in link for the recipient email used above. After signing in, open Shared with me. The active delivery appears there without requiring the original bearer link.

The delivery still expires after 30 days and disappears if the sender revokes it. Shared files remain owned by the sender and are not copied into the recipient's My Files library.

## Running the tests

Run the test suite:

```sh
bin/rails test
```

You now have a working local Campsend installation. Use the [deployment guide](../how-to/deploy.md) when you're ready to run it in production.
