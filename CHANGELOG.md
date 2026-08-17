# Changelog

## 1.0.0 (2026-08-16)

First public release.

### Features
- Connect directly to a Synology NAS using the Audio Station API
- Browse library: albums, artists, composers, genres, folders, all songs
- Streaming playback with background audio support (media-hub / sound indicator)
- Download songs for offline listening (offline mode)
- Playback queue with shuffle, repeat and play-next
- Session handling: re-login prompt on expired sessions, retry / offline-mode
  suggestions when the server is unreachable
- Settings: clear offline cache, full app reset to fresh-install state
- About page: author, website, contact, disclaimer and privacy statement
- Security: passwords are never stored, session tokens are not logged,
  cached file names are sanitized against path traversal, dialog content
  is HTML-escaped
