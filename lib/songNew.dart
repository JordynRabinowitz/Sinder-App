import 'dart:convert';
import 'package:http/http.dart' as http;

class Song {
  final String title;
  final String artist;
  final String spotifyUrl;
  bool hasBeenPlayed;
  final int releaseYear;


  Song({required this.title, required this.artist, required this.spotifyUrl, required this.hasBeenPlayed, required this.releaseYear});

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      title: json['title'],
      artist: json['artist'],
      spotifyUrl: json['spotifyUrl'],
      releaseYear: json['releaseYear'],
      hasBeenPlayed: json['hasBeenPlayed'] ?? false,
    );
  }
}

class SongFetcher {
  final String clientId = '92662ff7b8984515bc8861d2f805648c';
  final String clientSecret = '97e447110bf1458ab1beb40ba420f4c3';
  String? accessToken;

  // Step 1: Fetch Spotify access token
  Future<void> _getAccessToken() async {
    if (accessToken != null) return;

    final authResponse = await http.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: {
        'Authorization':
            'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (authResponse.statusCode == 200) {
      accessToken = jsonDecode(authResponse.body)['access_token'];
    } else {
      throw Exception('Failed to fetch Spotify access token');
    }
  }

  Future<String> getSpotifyAccessToken() async {
    if (accessToken != null) return accessToken!;
    await _getAccessToken();
    return accessToken!;
  }

  // Step 2: Fetch the artist's Spotify ID using the artist's name
  // Future<String?> fetchArtistId(String artistName) async {
  //   final token = await getSpotifyAccessToken();
  //   final response = await http.get(
  //     Uri.parse('https://api.spotify.com/v1/search?q=$artistName&type=artist'),
  //     headers: {'Authorization': 'Bearer $token'},
  //   );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['artists']['items'].isNotEmpty) {
        final artistId = data['artists']['items'][0]['id'];
        return artistId;
      }
    }
    return null;
  }

  // Step 3: Fetch the genres using the artist ID
  Future<List<String>> fetchGenres(String artistName) async {
    final artistId = await fetchArtistId(artistName);
    if (artistId == null) {
      throw Exception('Artist not found');
    }

    final token = await getSpotifyAccessToken();
    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/artists/$artistId'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List genres = data['genres'] ?? [];
      return List<String>.from(genres.map((g) => g.toString()));
    } else {
      throw Exception('Failed to fetch artist genres');
    }
  }
}

void main() async {
  final songFetcher = SongFetcher();

  // Test with a sample artist
  final artistName = "Ariana Grande";  // Example artist

  try {
    final genres = await songFetcher.fetchGenres(artistName);
    print('Genres for $artistName: $genres');
  } catch (e) {
    print('Error: $e');
  }
}
