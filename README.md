# uFawkesRes (Deprecated)

**This repository is deprecated and is being archived. Don't build on it, and
there is no successor yet.**

uFawkesRes was the suite's resource plane: a shared PostgreSQL database, a
Valkey cache, a Traefik ingress gateway and Authelia SSO on the
`fawkes-backbone-net` network. The suite no longer depends on it.

## What replaces it

Nothing has been chosen. The open question that matters most is the database
for [uFawkesDevX](https://github.com/paruff/uFawkesDevX), which used to
connect to this repo's Postgres. It's tracked in
[uFawkesDevX#57](https://github.com/paruff/uFawkesDevX/issues/57) and gates
that repo's `v0.1.0` (acceptance criterion AC-DEVX-01 in the suite plan).
Until it's decided, uFawkesDevX needs you to supply an external Postgres.

The previous README, with the setup steps, is in this repository's git
history, before the commit that deprecated it. The suite plan is at
[uFawkes.dev `docs/ai-sdlc/suite-release/`](https://github.com/paruff/uFawkes.dev/tree/main/docs/ai-sdlc/suite-release).
