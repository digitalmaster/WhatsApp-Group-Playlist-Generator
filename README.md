# Spotify Playlist Sync

This project contains a script to parse a WhatsApp group export txt file and sync Spotify tracks to a playlist.

## Files

- `parseSyncList.sh`: This is the main script that handles the parsing and syncing of tracks.

## How to Use

1. Export your WhatsApp group chat and name the file `_chat.txt`.
2. Move the `_chat.txt` file to the root of the project.
3. Export environment variable
    - `export SPOTIFY_CLIENT_ID=<your_client_id>`
    - `export SPOTIFY_CLIENT_SECRET=<your_client
    - `export SPOTIFY_PLAYLIST_ID=<your_playlist_id>`
    - `export SPOTIFY_REDIRECT_URI=<your_redirect_uri>`
4. Run the `parseSyncList.sh` script.
5. Will redirect you to a browser to authenticate with Spotify. After authenticating, you will be redirected to a page that will not load. Copy the `code` value from the URL and paste it into the terminal.

## Spotify API Documentation

For more information on how to use the Spotify API, please refer to the following resources:

- [Spotify for Developers](https://developer.spotify.com/)
- [Spotify Web API Reference](https://developer.spotify.com/documentation/web-api/reference/)
- [Spotify Web API Authorization Guide](https://developer.spotify.com/documentation/general/guides/authorization-guide/)
