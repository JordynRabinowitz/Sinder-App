# import requests
# import json
# import base64

# # Your app's credentials
# client_id = '92662ff7b8984515bc8861d2f805648c'
# client_secret = '97e447110bf1458ab1beb40ba420f4c3'
# playlist_id = '4WhvdMGhZfrvr3EWV6Tb1n'  # Replace with your playlist ID

# # Combine client ID and client secret to get the Authorization header
# client_credentials = f'{client_id}:{client_secret}'
# encoded_credentials = base64.b64encode(client_credentials.encode()).decode('utf-8')

# # Get the access token (this function should be in your script already)
# def get_access_token():
#     auth_url = 'https://accounts.spotify.com/api/token'
#     auth_data = {
#         'grant_type': 'client_credentials',
#         'client_id': client_id,
#         'client_secret': client_secret
#     }
#     auth_headers = {
#         'Content-Type': 'application/x-www-form-urlencoded'
#     }
#     response = requests.post(auth_url, data=auth_data, headers=auth_headers)
#     response_data = response.json()
#     return response_data['access_token']

# # Fetch track details from the playlist
# def fetch_track_details_from_playlist():
#     access_token = get_access_token()
#     playlist_url = f'https://api.spotify.com/v1/playlists/{playlist_id}/tracks'
#     headers = {
#         'Authorization': f'Bearer {access_token}'
#     }
#     response = requests.get(playlist_url, headers=headers)
#     tracks_data = response.json()
    
#     track_details = []
#     for item in tracks_data['items']:
#         track = item['track']
#         track_info = {
#             "title": track['name'],
#             "artist": track['artists'][0]['name'],
#             "albumCoverUrl": track['album']['images'][0]['url'] if track['album']['images'] else '',
#             "spotifyUrl": track['external_urls']['spotify'],
#             "genre": track['album']['genres'][0] if track['album'].get('genres') else 'Unknown',  # You can tweak this to match your exact format
#             "releaseYear": int(track['album']['release_date'].split("-")[0]),  # Assuming it's in YYYY-MM-DD format
#             "bpm": track['audio_features']['tempo'] if 'audio_features' in track else 0,  # Assuming audio features are available
#             "danceability": track['audio_features']['danceability'] if 'audio_features' in track else 0,
#             "energy": track['audio_features']['energy'] if 'audio_features' in track else 0,
#             "valence": track['audio_features']['valence'] if 'audio_features' in track else 0,
#             "acousticness": track['audio_features']['acousticness'] if 'audio_features' in track else 0,
#             "hasBeenPlayed": False
#         }
#         track_details.append(track_info)
    
#     return track_details

# # Save the track data to songs.json
# def save_tracks_to_json(track_details):
#     print("Attempting to save tracks...") 
#     try:
#         with open('..assets/songs.json', 'r') as file:
#             songs = json.load(file)
#     except (FileNotFoundError, json.JSONDecodeError):
#         songs = []

#     songs.extend(track_details)

#     with open('..assets/songs.json', 'w') as file:
#         json.dump(songs, file, indent=4)

#     print("Songs have been added to assets/songs.json")


import requests
import base64
import json
import os
import time

# Replace with your actual credentials
client_id = '92662ff7b8984515bc8861d2f805648c'
client_secret = '97e447110bf1458ab1beb40ba420f4c3'
playlist_id = '4WhvdMGhZfrvr3EWV6Tb1n'  # Replace with your playlist ID

# Path to your songs.json inside the Flutter project's assets folder
json_path = os.path.join('..', 'assets', 'songs.json')

# Store the access token and its expiry timestamp
access_token = None
token_expiry = None


def get_access_token(client_id, client_secret):
    global access_token, token_expiry
    # If token is valid and not expired, return it
    if access_token and time.time() < token_expiry:
        return access_token

    # Otherwise, request a new token
    client_credentials = f"{client_id}:{client_secret}"
    encoded_credentials = base64.b64encode(client_credentials.encode()).decode('utf-8')

    headers = {'Authorization': f'Basic {encoded_credentials}'}
    data = {'grant_type': 'client_credentials'}

    response = requests.post('https://accounts.spotify.com/api/token', headers=headers, data=data)
    response.raise_for_status()

    access_token = response.json()['access_token']
    expires_in = response.json()['expires_in']
    token_expiry = time.time() + expires_in

    return access_token


def get_playlist_tracks(access_token, playlist_id):
    headers = {'Authorization': f'Bearer {access_token}'}
    url = f'https://api.spotify.com/v1/playlists/{playlist_id}/tracks'
    tracks = []

    while url:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
        data = response.json()

        for item in data['items']:
            track = item['track']
            if not track:
                continue
            tracks.append({
                'id': track['id'],
                'title': track['name'],
                'artist': ', '.join([artist['name'] for artist in track['artists']]),
                'albumCoverUrl': track['album']['images'][0]['url'] if track['album']['images'] else '',
                'spotifyUrl': track['external_urls']['spotify'],
                'releaseYear': int(track['album']['release_date'].split('-')[0]),
                'hasBeenPlayed': False
            })

        url = data['next']
        time.sleep(0.1)

    return tracks


def get_audio_features(access_token, track_ids):
    headers = {'Authorization': f'Bearer {access_token}'}
    features = {}

    for i in range(0, len(track_ids), 100):
        batch = track_ids[i:i+100]
        ids_param = ','.join(batch)
        url = f'https://api.spotify.com/v1/audio-features?ids={ids_param}'
        response = requests.get(url, headers=headers)

        if response.status_code == 200:
            audio_features = response.json().get('audio_features', [])
            for feature in audio_features:
                if feature:
                    features[feature['id']] = {
                        'bpm': round(feature['tempo']),
                        'danceability': round(feature['danceability'], 2),
                        'energy': round(feature['energy'], 2),
                        'valence': round(feature['valence'], 2),
                        'acousticness': round(feature['acousticness'], 2)
                    }
        else:
            print(f"❌ Error fetching audio features: {response.json()}")

        time.sleep(0.1)

    return features


def merge_audio_features(tracks, audio_features):
    for song in tracks:
        af = audio_features.get(song['id'], {})
        song['bpm'] = af.get('bpm', 0)
        song['danceability'] = af.get('danceability', 0)
        song['energy'] = af.get('energy', 0)
        song['valence'] = af.get('valence', 0)
        song['acousticness'] = af.get('acousticness', 0)


def load_existing_songs(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return []


def save_songs(path, songs):
    with open(path, 'w') as f:
        json.dump(songs, f, indent=2)
    print(f"✅ Saved {len(songs)} total songs to {path}")


def main():
    access_token = get_access_token(client_id, client_secret)
    print("🔑 Access token acquired.")

    tracks = get_playlist_tracks(access_token, playlist_id)
    print(f"🎵 Fetched {len(tracks)} tracks from the playlist.")

    audio_features = get_audio_features(access_token, [track['id'] for track in tracks])
    merge_audio_features(tracks, audio_features)

    for t in tracks:
        print(f"➕ {t['title']} by {t['artist']}")

    existing_songs = load_existing_songs(json_path)
    existing_ids = {song['spotifyUrl'] for song in existing_songs}

    new_songs = [track for track in tracks if track['spotifyUrl'] not in existing_ids]
    all_songs = existing_songs + new_songs

    save_songs(json_path, all_songs)


if __name__ == '__main__':
    main()
