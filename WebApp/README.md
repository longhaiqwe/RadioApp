# RadioApp Web MVP

Browser client for `拾音 FM`.

The web MVP is intentionally focused: open the site, discover stations, and start listening fast. Song recognition starts with a lower-cost lyric ASR flow on the server.

## Scope

This version includes:

- station discovery
- station search
- browser playback with mini player and expanded player
- local favorites
- local recent plays
- lyric ASR song recognition for the currently playing station

This version does not include:

- ACRCloud/AudD recognition fallback
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
SUPABASE_SERVICE_ROLE_KEY=sb_service_role_replace_me
OPENROUTER_API_KEY=sk-or-replace-me
OPENROUTER_LYRIC_MODEL=xiaomi/mimo-v2.5
```

`SUPABASE_SERVICE_ROLE_KEY` must only be used by server-side route handlers.
The server helper still accepts the old `SUPABASE_SECRET_KEY` name as a fallback, but new setups should use the service-role name.

`OPENROUTER_API_KEY` is used only by the server-side recognition route. The recognition route expects `ffmpeg` to be available on the host so it can sample station streams into 16 kHz mono WAV before sending the audio to OpenRouter. Browser playback also uses `ffmpeg` when AAC+ or HLS streams need to be transcoded to MP3.

If `.env.local` is missing, the waitlist and recognition APIs will return error responses, but the station APIs and core listening flow will still work locally.

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
- Recognition samples the selected station stream server-side, extracts likely lyric snippets with OpenRouter, then searches NetEase for song candidates.
- Waitlist submissions are handled server-side and upserted into Supabase by email.

## Deployment

The target deployment for this MVP is Vercel.

Set these project environment variables in Vercel before enabling the waitlist route:

- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`
- `OPENROUTER_API_KEY`
- `OPENROUTER_LYRIC_MODEL`

Do not expose either value through `NEXT_PUBLIC_*`.

For recognition and browser playback transcoding, the deployment runtime must include `ffmpeg`. If the host does not provide it by default, package or install it as part of the deployment image.
