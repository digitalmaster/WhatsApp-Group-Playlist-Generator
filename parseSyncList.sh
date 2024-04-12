#!/bin/bash

# This script parses a WhatsApp group export txt file and syncs spotify tracks to a playlist

ACCESS_TOKEN='';
authorize(){
    echo "Authorizing Spotify..."

    local ACCESS_TOKEN_RESPONSE='';
    local ACCESS_ERROR='';

    # Open the Spotify authorization URL
    open "https://accounts.spotify.com/authorize?client_id=$SPOTIFY_CLIENT_ID&response_type=code&redirect_uri=$SPOTIFY_REDIRECT_URI&scope=playlist-modify-private%20playlist-modify-public"

    # Get the code from the redirect URI
    echo "Enter the code from the redirect URI:"
    read -r CODE

    ACCESS_TOKEN_RESPONSE=$(curl -s -X POST "https://accounts.spotify.com/api/token" \
        -H "Content-Type: application/x-www-form-urlencoded" \
        -H "Authorization: Basic $(echo -n "$SPOTIFY_CLIENT_ID:$SPOTIFY_CLIENT_SECRET" | base64)" \
        -d "grant_type=authorization_code&code=$CODE&redirect_uri=$SPOTIFY_REDIRECT_URI")
    echo "Access token response: $ACCESS_TOKEN_RESPONSE"

    # Get the access token
    ACCESS_TOKEN=$(echo $ACCESS_TOKEN_RESPONSE | jq -r '.access_token')
    ACCESS_ERROR=$(echo $ACCESS_TOKEN_RESPONSE | jq -r '.error')
    echo "Access error: $ACCESS_ERROR"

    if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_ERROR" != "null" ]; then
        echo "🚫 Failed to get access token 😢"
        exit 1
    else
        echo "✅ Successfully authorized 🔐"
    fi
}

TRACK_LIST=''
loadList(){
    # Parse the WhatsApp group export txt file and extract the spotify track links
    TRACK_LIST=$(grep -o 'https://open.spotify.com/track/[a-zA-Z0-9]*' < _chat.txt)
    local TRACK_DUPLICATES=$(echo "$TRACK_LIST" | sort | uniq -d)

    # Print duplicates
    if [ -n "$TRACK_DUPLICATES" ]; then
        # Print count of how many duplicates found
        echo "Found $(echo "$TRACK_DUPLICATES" | wc -l | tr -d '[:space:]') duplicate tracks"
    fi

    # Remove duplicates
    TRACK_LIST=$(echo "$TRACK_LIST" | sort -u)

    # Print number of tracks found
    echo "Found $(echo "$TRACK_LIST" | wc -l | tr -d '[:space:]') tracks"
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
    for group_list_string in "${TRACK_LIST_GROUPS[@]}"; do
        #split the string by space and count the number of items
        group_list_length=$(echo "$group_list_string" | wc -w)
        echo "Adding: $group_list_length tracks to playlist..."

        echo "Adding tracks to playlist: $group_list_string"
        array_string=$(convertSpotifyURIsToArrayString "$group_list_string")
        curl -X POST "https://api.spotify.com/v1/playlists/$SPOTIFY_PLAYLIST_ID/tracks" \
            -H "Authorization: Bearer $ACCESS_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"uris\": $array_string}"
    done
}

authorize
loadList
TRACK_LIST=$(convertToSpotifyURIs)
TRACK_LIST_GROUPS=()
createTrackListGroups
updatePlaylist
exit 0
