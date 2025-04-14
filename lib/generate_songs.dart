import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

// Replace these with your actual Spotify API credentials
const clientId = '92662ff7b8984515bc8861d2f805648c';
const clientSecret = '97e447110bf1458ab1beb40ba420f4c3';

// Replace with actual Spotify track URLs
final List<String> spotifyTrackUrls = [
  'https://open.spotify.com/track/4uLU6hMCjMI75M1A2tKUQC',
  'https://open.spotify.com/track/1301WleyT98MSxVHPZCA6M',
];

Future<void> main() async {
  final accessToken = await getAccessToken();
  final List<Map<String, dynamic>> songs = [];

  for (String url in spotifyTrackUrls) {
    final trackId = extractTrackId(url);
    final metadata = await fetchTrackMetadata(trackId, accessToken);
    final features = await fetchAudioFeatures(trackId, accessToken);

    if (metadata == null || features == null) {
      print("❌ Skipping track $trackId due to missing metadata or features.");
      continue;
    }

    final artistId = metadata['artists'][0]['id'];
    final artistGenres = await fetchArtistGenres(artistId, accessToken);
    if (artistGenres.isEmpty) {
      print("❌ Skipping track $trackId due to missing genres.");
      continue;
    }

    final genre = artistGenres.first;

    songs.add({
      'title': metadata['name'],
      'artist': metadata['artists'][0]['name'],
      'albumCoverUrl': metadata['album']['images'][0]['url'],
      'spotifyUrl': metadata['external_urls']['spotify'],
      'genres': [genre],
      'releaseYear': DateTime.parse(metadata['album']['release_date']).year,
      'bpm': features['tempo'].toInt(),
      'danceability': features['danceability'],
      'energy': features['energy'],
      'valence': features['valence'],
      'acousticness': features['acousticness'],
      'hasBeenPlayed': false,
    });
  }

  final file = File('assets/songs.json');
  await file.writeAsString(JsonEncoder.withIndent('  ').convert(songs));
  print("✅ songs.json updated with ${songs.length} songs.");
}

Future<String> getAccessToken() async {
  final response = await http.post(
    Uri.parse('https://accounts.spotify.com/api/token'),
    headers: {
      'Authorization':
          'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
      'Content-Type': 'application/x-www-form-urlencoded',
    },
    body: {'grant_type': 'client_credentials'},
  );

  if (response.statusCode == 200) {
    return jsonDecode(response.body)['access_token'];
  } else {
    throw Exception('Failed to get Spotify access token');
  }
}

String extractTrackId(String url) {
  final uri = Uri.parse(url);
  return uri.pathSegments.last;
}

Future<Map<String, dynamic>?> fetchTrackMetadata(String id, String token) async {
  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/tracks/$id'),
    headers: {'Authorization': 'Bearer $token'},
  );

  return response.statusCode == 200 ? jsonDecode(response.body) : null;
}

Future<Map<String, dynamic>?> fetchAudioFeatures(String id, String token) async {
  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/audio-features/$id'),
    headers: {'Authorization': 'Bearer $token'},
  );

  return response.statusCode == 200 ? jsonDecode(response.body) : null;
}

Future<List<String>> fetchArtistGenres(String artistId, String token) async {
  final response = await http.get(
    Uri.parse('https://api.spotify.com/v1/artists/$artistId'),
    headers: {'Authorization': 'Bearer $token'},
  );

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    return List<String>.from(json['genres']);
  } else {
    return [];
  }
}


