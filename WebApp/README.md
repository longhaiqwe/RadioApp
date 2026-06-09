# RadioApp Web MVP

Browser client for `拾音 FM`.

The web MVP is intentionally focused: open the site, discover stations, and start listening fast. Song recognition stays as a macOS-directed upgrade path for now.

## Scope

This version includes:

- station discovery
- station search
- browser playback with mini player and expanded player
- local favorites
- local recent plays
- macOS waitlist capture for recognition interest

This version does not include:

- web song recognition
- web payments or subscriptions
- account sync
- iOS distribution

## Development

```bash
npm install
npm run dev
```

Open [http://127.0.0.1:3000](http://127.0.0.1:3000).

## Environment

Copy `.env.example` to `.env.local` and set:

```dotenv
SUPABASE_URL=https://example.supabase.co
SUPABASE_SECRET_KEY=sb_secret_replace_me
```

`SUPABASE_SECRET_KEY` must only be used by server-side route handlers.

If `.env.local` is missing, the waitlist API will return an error response, but the station APIs and core listening flow will still work locally.

## Checks

```bash
npm run test
npm run lint
npm run build
npm run e2e
```

## Project Notes

- UI tokens and visual language are ported from the existing SwiftUI neon/glass design system.
- Favorites, recent plays, and volume are stored locally in the browser.
- `radio-browser.info` data is proxied through Next.js route handlers instead of being fetched directly in UI components.
- Waitlist submissions are handled server-side and upserted into Supabase by email.
