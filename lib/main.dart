import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:sinder/generate_songs.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/link.dart';
import 'package:http/http.dart' as http;

import 'song.dart';
import 'song_detail.dart';
import 'urlLauncher.dart';

// Declare accessToken globally
String? accessToken;

// Caches for album covers and artist genres
Map<String, String> albumCoverUrls = {};
Map<String, List<String>> artistGenresCache = {};

Future<void> _getAccessToken() async {
  if (accessToken != null) return;
  //jordynjr ids
  // const clientId = '92662ff7b8984515bc8861d2f805648c';
  // const clientSecret = '97e447110bf1458ab1beb40ba420f4c3';

  //jora8609 ids
  const clientId = '0076e155b3ed4ae59b1fa975dbb9ca62';
  const clientSecret = 'ac4b0062c8e4406faa4573f75a76addb';

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

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sinder',
      theme: ThemeData(
        primarySwatch: Colors.red,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 5), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SongSwiperScreen()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.asset('assets/tinder_to_sinder.jpg'),
      ),
    );
  }
}

class SongSwiperScreen extends StatefulWidget {
  @override
  _SongSwiperScreenState createState() => _SongSwiperScreenState();
}

class _SongSwiperScreenState extends State<SongSwiperScreen> {
  List<Song> songs = [];
  List<Song> likedSongs = [];
  Future<void>? _launched;

  @override
  void initState() {
    super.initState();
    loadSongs();
  }

  Future<void> loadSongs() async {
    final String response = await rootBundle.loadString('assets/songs.json');
    final List<dynamic> data = json.decode(response);
    setState(() {
      songs = data.map((e) => Song.fromJson(e)).toList();
    });
  }

  String _extractTrackId(String spotifyUrl) {
    final uri = Uri.parse(spotifyUrl);
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.last : '';
  }

  Future<String?> fetchArtistIdFromTrackId(String trackId) async {
    await _getAccessToken(); // Ensure you have a valid access token
    final url = Uri.parse('https://api.spotify.com/v1/tracks/$trackId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final artists = data['artists'] as List<dynamic>;
      if (artists.isNotEmpty && artists[0]['id'] != null) {
        return artists[0]['id'] as String;
      }
    }

    return '0';
  }

  Future<List<String>> fetchArtistGenres(String artistId) async {
    if (artistGenresCache.containsKey(artistId)) {
      return artistGenresCache[artistId]!;
    }

    await _getAccessToken();
    if (artistId == '0') {
      return ['no genres found'];
    }

    final url = Uri.parse('https://api.spotify.com/v1/artists/$artistId');
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final genres = List<String>.from(data['genres']);
      artistGenresCache[artistId] = genres;
      return genres;
    } else {
      print('Failed to load artist genres for $artistId');
      return [];
    }
  }

  Future<String> fetchAlbumCover(String trackId) async {
    if (albumCoverUrls.containsKey(trackId)) {
      return albumCoverUrls[trackId]!;
    }

    await _getAccessToken();
    final trackResponse = await http.get(
      Uri.parse('https://api.spotify.com/v1/tracks/$trackId'),
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (trackResponse.statusCode == 200) {
      final data = jsonDecode(trackResponse.body);
      final imageUrl = data['album']['images'][0]['url'];
      albumCoverUrls[trackId] = imageUrl;
      return imageUrl;
    } else {
      throw Exception('Failed to fetch album cover');
    }
  }

  Future<void> _launchSpotifyUrl(String url) async {
    final Uri finalUrl = Uri.parse(url);
    if (!await launchUrl(
      finalUrl,
      mode: LaunchMode.externalApplication,
    )) {
      throw Exception('Could not launch $finalUrl');
    }
  }

  Future<bool> handleSwipe(int previousIndex, int? currentIndex, CardSwiperDirection direction) async {
    final swipedSong = songs[previousIndex];
    setState(() {
      swipedSong.hasBeenPlayed = true;
    });

    if (direction == CardSwiperDirection.right) {
      likedSongs.add(swipedSong);
      Song? recommendedSong = recommendSimilarSong(swipedSong);

      if (recommendedSong != null) {
        setState(() {
          songs.removeWhere((song) => song.title == recommendedSong.title);
          songs.insert(previousIndex + 1, recommendedSong);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Recommended: ${recommendedSong.title}")),
        );
      }
    }

    return true;
  }

  Song? recommendSimilarSong(Song liked) {
    List<Song> unplayed = songs.where((s) => !s.hasBeenPlayed && s != liked).toList();

    if (unplayed.isEmpty) return null;

    unplayed.sort((a, b) {
      double distA = euclideanDistance(liked, a);
      double distB = euclideanDistance(liked, b);
      return distA.compareTo(distB);
    });

    return unplayed.first;
  }

  Map<String, double> genreMap = {
    "pop": 1.0,
    "electronic": 1.1,
    "rock": 2.0,
    "hip hop": 3.0,
    "jazz": 4.0,
    "classical": 5.0,
    "indie": 6.0,
    "metal": 7.0,
    "blues": 8.0,
    "country": 9.0,
    "reggae": 10.0,
  };

  double euclideanDistance(Song a, Song b) {
    double genreA = genreMap[a.genres.join(',').toLowerCase()] ?? 0.0;
    double genreB = genreMap[b.genres.join(',').toLowerCase()] ?? 0.0;

    return sqrt(
      pow(genreA - genreB, 2) +
      pow(a.releaseYear - b.releaseYear, 2) +
      pow(a.bpm - b.bpm, 2) +
      pow(a.danceability - b.danceability, 2) +
      pow(a.energy - b.energy, 2) +
      pow(a.valence - b.valence, 2) +
      pow(a.acousticness - b.acousticness, 2)
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sinder")),
      body: songs.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : CardSwiper(
              cardsCount: songs.length,
              allowedSwipeDirection: const AllowedSwipeDirection.only(
                left: true,
                right: true,
              ),
              onSwipe: handleSwipe,
              cardBuilder: (context, index, _, __) {
                final song = songs[index];
                final trackId = _extractTrackId(song.spotifyUrl);

                return FutureBuilder<String?>( // Fetching artist ID
                  future: fetchArtistIdFromTrackId(trackId),
                  builder: (context, artistIdSnapshot) {
                    if (artistIdSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    return FutureBuilder<List<String>>( // Fetching artist genres
                      future: fetchArtistGenres(artistIdSnapshot.data!),
                      builder: (context, genresSnapshot) {
                        List<String> genres = genresSnapshot.data ?? [];

                        return Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: MediaQuery.of(context).size.height * 0.75,
                            child: Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              child: SingleChildScrollView(
                                child: Column(
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 1,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: FutureBuilder<String>( // Fetching album cover
                                          future: fetchAlbumCover(trackId),
                                          builder: (context, snapshot) {
                                            if (snapshot.connectionState == ConnectionState.waiting) {
                                              return const Center(child: CircularProgressIndicator());
                                            } else if (snapshot.hasData) {
                                              return Image.network(snapshot.data!, fit: BoxFit.cover);
                                            } else {
                                              return const Icon(Icons.music_note, size: 64);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(song.title, style: Theme.of(context).textTheme.titleLarge),
                                    Text("Artist: ${song.artist}"),
                                    Text("Year: ${song.releaseYear}"),
                                    genres.isNotEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            genres.join(', '),
                                            style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
                                          ),
                                        )
                                      : const Padding(
                                          padding: EdgeInsets.only(top: 4.0),
                                          child: Text(
                                            'No genre found',
                                            style: TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ),
                                    const SizedBox(height: 12),
                                    ElevatedButton(
                                      onPressed: () => setState(() {
                                        _launched = _launchSpotifyUrl(song.spotifyUrl);
                                      }),
                                      child: const Text('Open on Spotify'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => SongDetailPage(trackId: trackId),
                                          ),
                                        );
                                      },
                                      child: const Text("See Details"),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
