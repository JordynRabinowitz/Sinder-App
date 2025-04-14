import 'dart:math';

class Song {
  final String title;
  final String artist;
  final String albumCoverUrl;
  final String spotifyUrl;
  final List<String> genres; // Changed genre to a List of Strings
  final int releaseYear;
  final int bpm;
  final double danceability;
  final double energy;
  final double valence;
  final double acousticness;
  bool hasBeenPlayed;

  Song({
    required this.title,
    required this.artist,
    required this.albumCoverUrl,
    required this.spotifyUrl,
    required this.genres, // Now accepting a list of genres
    required this.releaseYear,
    required this.bpm,
    required this.danceability,
    required this.energy,
    required this.valence,
    required this.acousticness,
    this.hasBeenPlayed = false,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      title: json['title'] ?? 'Unknown Title',
      artist: json['artist'] ?? 'Unknown Artist',
      albumCoverUrl: json['albumCoverUrl'] ?? '',
      spotifyUrl: json['spotifyUrl'] ?? '',
      genres: List<String>.from(json['genres'] ?? []), // Fixed: genre is now a list
      releaseYear: json['releaseYear'] ?? 0,
      bpm: (json['bpm'] ?? 0).toInt(),
      danceability: (json['danceability'] ?? 0.0).toDouble(),
      energy: (json['energy'] ?? 0.0).toDouble(),
      valence: (json['valence'] ?? 0.0).toDouble(),
      acousticness: (json['acousticness'] ?? 0.0).toDouble(),
      hasBeenPlayed: json['hasBeenPlayed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'artist': artist,
      'albumCoverUrl': albumCoverUrl,
      'spotifyUrl': spotifyUrl,
      'genres': genres, // Now a list of genres
      'releaseYear': releaseYear,
      'bpm': bpm,
      'danceability': danceability,
      'energy': energy,
      'valence': valence,
      'acousticness': acousticness,
      'hasBeenPlayed': hasBeenPlayed,
    };
  }

  List<double> toVector() {
    return [
      genres.length.toDouble(),  // Use the number of genres (or a custom scoring)
      releaseYear.toDouble(),
      bpm.toDouble(),
      danceability,
      energy,
      valence,
      acousticness,
    ];
  }

  // Converts the song to a map for genre-based comparisons
  Map<String, dynamic> toMap() {
    return {
      'spotifyUrl': spotifyUrl,
      'genres': genres,
      'title': title,
    };
  }

  static double cosineSimilarity(List<double> a, List<double> b) {
    double dotProduct = 0;
    double aMagnitude = 0;
    double bMagnitude = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      aMagnitude += a[i] * a[i];
      bMagnitude += b[i] * b[i];
    }

    return dotProduct / (sqrt(aMagnitude) * sqrt(bMagnitude));
  }
}
