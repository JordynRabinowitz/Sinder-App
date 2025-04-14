import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Make sure this function is defined somewhere accessible
Future<String> getAccessToken() async {
  // Replace with your actual logic to get access token
  return 'your_access_token_here';
}

class SongDetailPage extends StatefulWidget {
  final String trackId;
  const SongDetailPage({required this.trackId, Key? key}) : super(key: key);

  @override
  _SongDetailPageState createState() => _SongDetailPageState();
}

class _SongDetailPageState extends State<SongDetailPage> {
  late Future<Map<String, dynamic>> trackData;

  @override
  void initState() {
    super.initState();
    trackData = getTrackDetails(widget.trackId);
  }

  Future<Map<String, dynamic>> getTrackDetails(String trackId) async {
    final accessToken = await getAccessToken();

    final response = await http.get(
      Uri.parse('https://api.spotify.com/v1/tracks/$trackId'),
      headers: {
        'Authorization': 'Bearer $accessToken',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load track details');
    }
  }

  String getAlbumImageUrl(Map<String, dynamic> trackData) {
    var images = trackData['album']['images'];
    return images[0]['url'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Song Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: trackData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (snapshot.hasData) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.network(
                  getAlbumImageUrl(snapshot.data!),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) {
                      return child;
                    }
                    return Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                (loadingProgress.expectedTotalBytes ?? 1)
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset('assets/images/default_album.png');
                  },
                ),
                SizedBox(height: 20),
                Text(
                  snapshot.data!['name'] ?? 'Unknown Title',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  'Artist: ${snapshot.data!['artists'][0]['name']}',
                  style: TextStyle(fontSize: 16),
                ),
              ],
            );
          } else {
            return Center(child: Text('No data available'));
          }
        },
      ),
    );
  }
}
