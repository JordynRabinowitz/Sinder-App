import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SpotifyLinkScreen extends StatelessWidget {
  final String spotifyUrl;

  SpotifyLinkScreen({required this.spotifyUrl});

  // Function to launch Spotify URL
  Future<void> _launchURL() async {
    if (await canLaunch(spotifyUrl)) {
      await launch(spotifyUrl, forceSafariVC: false, forceWebView: false);
    } else {
      throw 'Could not launch $spotifyUrl';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Open Spotify Link'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: _launchURL,
          child: Text('Open Spotify Link'),
        ),
      ),
    );
  }
}
