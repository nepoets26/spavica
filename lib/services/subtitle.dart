import 'package:http/http.dart' as http;
import 'dart:convert';

class SubtitleText {
  final double startTime;
  final double duration;
  final String text;

  SubtitleText({
    required this.startTime,
    required this.duration,
    required this.text,
  });

  double get endTime => startTime + duration;
}

class YouTubeSubtitle {
  static const String apiKey = '1ab00107c9msh25f0f3fbd282693p16b8c7jsn09879631f352';
  static const String apiHost = 'youtube-media-downloader.p.rapidapi.com';

  Future<List<SubtitleInfo>> getSubtitleInfo(String videoUrl) async {
    try {
      final videoId = extractVideoId(videoUrl);
      print('Video ID: $videoId');

      if (videoId == null) {
        throw Exception('Invalid YouTube URL');
      }

      final Uri uri = Uri.parse('https://$apiHost/v2/video/details')
          .replace(queryParameters: {
        'videoId': videoId,
      });

      print('Request URL: $uri');

      final response = await http.get(
        uri,
        headers: {
          'X-RapidAPI-Key': apiKey,
          'X-RapidAPI-Host': apiHost,
        },
      );

      print('Response Status Code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        print('Full Response Data: ${json.encode(responseData)}');

        final subtitles = responseData['subtitles'] as Map<String, dynamic>;
        print('Subtitles Data: ${json.encode(subtitles)}');

        if (subtitles['status'] == true && subtitles['items'] is List) {
          final items = subtitles['items'] as List;
          if (items.isNotEmpty) {
            // Trả về danh sách tất cả các subtitle có sẵn
            return items.map((item) => SubtitleInfo(
              url: item['url'] as String,
              language: item['text'] as String,
              languageCode: item['code'] as String,
            )).toList();
          }
        }
        throw Exception('No subtitles available for this video');
      } else {
        print('Error Response: ${response.body}');
        throw Exception('Failed to load video info: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception caught: $e');
      throw Exception('Error getting subtitle info: $e');
    }
  }

  Future<String> getSubtitleContent(String subtitleUrl) async {
    try {
      print('Fetching subtitles from URL: $subtitleUrl');

      final response = await http.get(Uri.parse(subtitleUrl));
      print('Subtitle Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('Subtitle Content: ${response.body}');
        return response.body;
      } else {
        print('Subtitle Error Response: ${response.body}');
        throw Exception('Failed to load subtitles: ${response.statusCode}');
      }
    } catch (e) {
      print('Subtitle Exception: $e');
      throw Exception('Error getting subtitle content: $e');
    }
  }

  List<SubtitleText> parseSubtitleXml(String xmlContent) {
    final subtitles = <SubtitleText>[];

    final RegExp textTagRegex = RegExp(r'<text start="([\d.]+)" dur="([\d.]+)">(.*?)</text>');
    final matches = textTagRegex.allMatches(xmlContent);

    for (final match in matches) {
      final startTime = double.parse(match.group(1)!);
      final duration = double.parse(match.group(2)!);
      final text = match.group(3)!
          .replaceAll('&amp;#39;', "'")
          .replaceAll('&amp;', "&");

      subtitles.add(SubtitleText(
        startTime: startTime,
        duration: duration,
        text: text,
      ));
    }

    return subtitles;
  }

  String getSubtitleByTimeRange(String xmlContent, double startTime, double endTime) {
    if (startTime < 0) startTime = 0;
    if (endTime < startTime) throw Exception('End time must be greater than start time');

    final subtitles = parseSubtitleXml(xmlContent);

    final filteredSubtitles = subtitles.where((subtitle) {
      return !(subtitle.endTime < startTime || subtitle.startTime > endTime);
    }).toList();

    filteredSubtitles.sort((a, b) => a.startTime.compareTo(b.startTime));

    final StringBuffer result = StringBuffer();
    for (final subtitle in filteredSubtitles) {
      final formattedStart = _formatTime(subtitle.startTime);
      final formattedEnd = _formatTime(subtitle.endTime);
      result.writeln('[$formattedStart --> $formattedEnd]');
      result.writeln(subtitle.text);
      result.writeln();
    }

    return result.toString();
  }

  String _formatTime(double seconds) {
    final Duration duration = Duration(milliseconds: (seconds * 1000).round());
    final int hours = duration.inHours;
    final int minutes = duration.inMinutes.remainder(60);
    final int secs = duration.inSeconds.remainder(60);
    final int ms = duration.inMilliseconds.remainder(1000);

    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${secs.toString().padLeft(2, '0')},'
        '${ms.toString().padLeft(3, '0')}';
  }

  String? extractVideoId(String url) {
    try {
      RegExp regExp = RegExp(
          r'^.*((youtu.be\/)|(v\/)|(\/u\/\w\/)|(embed\/)|(watch\?))\??v?=?([^#&?]*).*/');
      Match? match = regExp.firstMatch(url);
      String? videoId = match?.group(7);

      if (videoId == null) {
        RegExp shortUrlRegExp = RegExp(r'youtu\.be/([^?]+)');
        match = shortUrlRegExp.firstMatch(url);
        videoId = match?.group(1);
      }

      if (videoId == null && url.length == 11) {
        return url;
      }

      print('Extracted Video ID: $videoId');
      return videoId;
    } catch (e) {
      print('Video ID Extraction Error: $e');
      return null;
    }
  }
}

class SubtitleInfo {
  final String url;
  final String language;
  final String languageCode;

  SubtitleInfo({
    required this.url,
    required this.language,
    required this.languageCode,
  });
}