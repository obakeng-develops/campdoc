# Campsend

Read the lode in `docs/lode/` before you make changes.

**[Terminology](docs/lode/terminology.md)**: `Send` is the model, "delivery" is the domain word, and the two controller families split by audience. Start here.

**[Practices](docs/lode/practices.md)**: the `Campsend.policy` extension seam, one wide event per request, how to run the tests, and the compromises that are deliberate.

Campsend is the public half of two distributions. A private managed distribution pins this repo as a submodule, so behavior that both need lands here first.

Run `bin/ci` before you open a PR.

User-facing documentation lives under `docs/` and follows Diátaxis.
