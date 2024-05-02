#!/bin/bash

# This script parses a WhatsApp group export txt file and syncs spotify tracks to a playlist

parseCodeFromRedirectURL(){
    local URL=$1
    local CODE=''

    # Extract the code from the URL
    CODE=$(echo "$URL" | grep -o 'code=[^&]*' | cut -d'=' -f2)

    echo "$CODE"
}

ACCESS_TOKEN='';
authorize(){
    echo "Authorizing Spotify..."

    local ACCESS_TOKEN_RESPONSE='';
    local ACCESS_ERROR='';
    local CODE='';

    # Open the Spotify authorization URL
    open "https://accounts.spotify.com/authorize?client_id=$SPOTIFY_CLIENT_ID&response_type=code&redirect_uri=$SPOTIFY_REDIRECT_URI&scope=playlist-modify-private%20playlist-modify-public"

    # Get the code from the redirect URL
    echo "Enter the redirect URL:"
    read -r CODE_INPUT

    CODE=$(parseCodeFromRedirectURL "$CODE_INPUT")
    echo "Code outside: $CODE"

    ACCESS_TOKEN_RESPONSE=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Authorization: Basic $(echo -n "$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET" | base64)" \
        -d "grant_type=authorization_code&code=$CODE&redirect_uri=$SPOTIFY_REDIRECT_URI")

    # Get the access token
    ACCESS_TOKEN=$(echo $ACCESS_TOKEN_RESPONSE | jq -r '.access_token')
    ACCESS_ERROR=$(echo $ACCESS_TOKEN_RESPONSE | jq -r '.error')

    if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_ERROR" != "null" ]; then
        echo "Access error: $ACCESS_ERROR"
        echo "🚫 Failed to get access token 😢"
        exit 1
    else
        echo "✅ Successfully authorized 🔐"
    fi
}

removeTracksAlreadyInPlaylist(){
    local TRACK_LIST=$1

    # Convert existing track IDs into a grep-friendly pattern
    local PATTERN=$(echo "$EXISTING_TRACKS" | sed 's/ /\\|/g')

    # Filter TRACK_LIST by removing entries matching the pattern
    local FILTERED_TRACK_LIST=$(echo "$TRACK_LIST" | grep -v "$PATTERN")

    echo "$FILTERED_TRACK_LIST"
}

TRACK_LIST=''
loadList(){
    local TRACK_DUPLICATES=''
    # Parse the WhatsApp group export txt file and extract the spotify track links
    TRACK_LIST=$(grep -o 'https://open.spotify.com/track/[a-zA-Z0-9]*' < _chat.txt)

    TRACK_DUPLICATES=$(echo "$TRACK_LIST" | sort | uniq -d)

    # Print duplicates
    if [ -n "$TRACK_DUPLICATES" ]; then
        # Print count of how many duplicates found
        echo "Found $(echo "$TRACK_DUPLICATES" | wc -l | tr -d '[:space:]') duplicate tracks"
    fi

    # Remove duplicates while maintaining order
    TRACK_LIST=$(echo "$TRACK_LIST" | awk '!seen[$0]++')

    # Print number of tracks found
    echo "Found $(echo "$TRACK_LIST" | wc -l | tr -d '[:space:]') tracks"

    # Remove tracks already in the playlist
    TRACK_LIST_COUNT_BEFORE=$(echo "$TRACK_LIST" | wc -l | tr -d '[:space:]');
    TRACK_LIST=$(removeTracksAlreadyInPlaylist "$TRACK_LIST")

    if [ -z "$TRACK_LIST" ]; then
        echo "✅ All $TRACK_LIST_COUNT_BEFORE already added. No new tracks to add"
        exit 0
    fi

    TRACK_LIST_COUNT_AFTER=$(echo "$TRACK_LIST" | wc -l | tr -d '[:space:]');
    echo "✨ Found $TRACK_LIST_COUNT_AFTER new tracks to add 🎵"
    echo "$TRACK_LIST"
}

fetchTracks(){
    local PLAYLIST_TRACKS_RESPONSE=''

    PLAYLIST_TRACKS_RESPONSE=$(curl -s -X GET "$1" \
        -H "Authorization: Bearer $ACCESS_TOKEN")

    echo "$PLAYLIST_TRACKS_RESPONSE"
}


fetchExistingTracks(){
    echo "Fetching existing tracks from the playlist..."

    local FETCH_RESPONSE=''
    local NEXT_URL=''
    local EXISTING_TRACKS_COUNT=''

    FETCH_RESPONSE=$(fetchTracks "https://api.spotify.com/v1/playlists/$SPOTIFY_PLAYLIST_ID/tracks?limit=100&offset=0")

    FETCH_ERROR=$(echo "$FETCH_RESPONSE" | jq -r '.error')

    if [ "$FETCH_ERROR" != "null" ]; then
        echo "Fetch error: $FETCH_ERROR"
        echo "Response: $FETCH_RESPONSE"
        echo "🚫 Failed to fetch existing tracks 😢"
        exit 1
    fi
    EXISTING_TRACKS=$(echo "$FETCH_RESPONSE" | jq -r '.items[].track.id');
    NEXT_URL=$(echo "$FETCH_RESPONSE" | jq -r '.next')

    while [ "$NEXT_URL" != "null" ]; do
        echo "Fetching next page of tracks: $NEXT_URL"
        FETCH_RESPONSE=$(fetchTracks "$NEXT_URL")
        FETCH_ERROR=$(echo "$FETCH_RESPONSE" | jq -r '.error')

        if [ "$FETCH_ERROR" != "null" ]; then
            echo "Fetch error: $FETCH_ERROR"
            echo "Response: $FETCH_RESPONSE"
            echo "🚫 Failed to fetch existing tracks 😢"
            exit 1
        fi

        EXISTING_TRACKS+=$'\n'
        EXISTING_TRACKS+="$(echo "$FETCH_RESPONSE" | jq -r '.items[].track.id')"
        NEXT_URL=$(echo "$FETCH_RESPONSE" | jq -r '.next')
    done

    EXISTING_TRACKS_COUNT=$(echo "$EXISTING_TRACKS" | wc -l | tr -d '[:space:]')
    echo "✅ Successfully fetched $EXISTING_TRACKS_COUNT existing tracks 🎵"
}

convertToSpotifyURIs(){
    echo $(echo "$TRACK_LIST" | sed 's|https://open.spotify.com/track/|spotify:track:|g')
}

convertSpotifyURIsToArrayString(){
    echo "[\""$(echo "$1" | sed 's| |", "|g')"\"]"
}

createTrackListGroups(){
    # Spotify has a limit of 100 tracks per request so we need to split the list into groups of 100
    while IFS= read -r line; do
        TRACK_LIST_GROUPS+=("$line")
    done < <(echo "$TRACK_LIST" | xargs -n 100)

    echo "Created $(echo "${#TRACK_LIST_GROUPS[@]}") groups of tracks"
}

updatePlaylist(){
    echo "Updating playlist..."
    for group_list_string in "${TRACK_LIST_GROUPS[@]}"; do
        #split the string by space and count the number of items
        group_list_length=$(echo "$group_list_string" | wc -w)
        echo "Adding: $group_list_length tracks to playlist..."

        array_string=$(convertSpotifyURIsToArrayString "$group_list_string")
        response=$(curl -s -X POST "https://api.spotify.com/v1/playlists/$SPOTIFY_PLAYLIST_ID/tracks" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"uris\": $array_string}")
        response_error=$(echo "$response" | jq -r '.error')

        if [ "$response_error" != "null" ]; then
            echo "Response error: $response_error"
            echo "Response: $response"
            echo "🚫 Failed to update playlist 😢"
            exit 1
        fi
    done

    echo "✅ Successfully updated playlist 🎵"
}

authorize
EXISTING_TRACKS=''
fetchExistingTracks
loadList
TRACK_LIST=$(convertToSpotifyURIs)
TRACK_LIST_GROUPS=()
createTrackListGroups
updatePlaylist
exit 0
