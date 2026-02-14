import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ==============================================================================
// CONFIGURATION
// ==============================================================================
const String defaultShortcode = 'DOddmpskl5Z'; // Default for testing

// User's provided cookie
const String cookie =
    'csrftoken=aRv0kba2VEd3GD6ZkabCam; datr=GyGQaXeNGFH_-S7UYbQUDPl7; ig_did=CCCE129C-0329-4678-AD28-8680125A89F8; dpr=1.25; mid=aZAhGwALAAGYfG-QzwwCdV_d_BlP; ig_nrcb=1; ps_l=1; ps_n=1; wd=587x730';

const String userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36';
// ==============================================================================

void main(List<String> args) async {
  String targetShortcode = defaultShortcode;
  String initialUrl =
      'https://www.instagram.com/reel/$defaultShortcode/'; // Default URL

  if (args.isNotEmpty) {
    final input = args[0];
    // Regex to extract shortcode from URL (e.g., /p/SHORTCODE, /reel/SHORTCODE, /tv/SHORTCODE)
    final match = RegExp(
      r'(?:instagram\.com\/(?:p|reel|tv)\/)([a-zA-Z0-9_-]+)',
    ).firstMatch(input);
    if (match != null) {
      targetShortcode = match.group(1)!;
      initialUrl = input; // Use provided URL directly
    } else {
      // If no URL pattern matched, assume the argument itself is the shortcode
      targetShortcode = input;
      initialUrl = 'https://www.instagram.com/reel/$targetShortcode/';
    }
  }

  print('=============================================');
  print('   Instagram Video Downloader (Debug Mode)   ');
  print('=============================================');
  print('Target URL: $initialUrl');
  print('Target Shortcode: $targetShortcode');
  print('Cookies: ${cookie.isNotEmpty ? "Provided" : "None"}');

  String? finalVideoUrl;
  final client = http.Client();

  final headers = {
    'Authority': 'www.instagram.com',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Cache-Control': 'no-cache',
    'Pragma': 'no-cache',
    'Sec-Ch-Ua':
        '"Not.A/Brand";v="8", "Chromium";v="114", "Google Chrome";v="114"',
    'Sec-Ch-Ua-Mobile': '?0',
    'Sec-Ch-Ua-Platform': '"Windows"',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Upgrade-Insecure-Requests': '1',
    'User-Agent': userAgent,
  };

  if (cookie.isNotEmpty) {
    headers['Cookie'] = cookie;
  }

  // ==============================================================================
  // Strategy 1: Main Page Extraction
  // ==============================================================================
  print('\n[1] Strategy: Parsing Main Page HTML...');
  final url = initialUrl;

  try {
    final response = await client.get(Uri.parse(url), headers: headers);
    if (response.statusCode == 200) {
      final body = response.body;

      // Debug Save
      await File('debug_main_page.html').writeAsString(body);

      // Check 1: Open Graph Video
      final ogVideoMatch = RegExp(
        r'<meta property="og:video" content="(.*?)" />',
      ).firstMatch(body);
      if (ogVideoMatch != null) {
        finalVideoUrl = ogVideoMatch.group(1);
        print('Success: Found video_url in og:video tag.');
      }

      // Check 2: SharedData Regex
      if (finalVideoUrl == null) {
        final regex = RegExp(r'"video_url"\s*:\s*"(.*?)"');
        final match = regex.firstMatch(body);
        if (match != null) {
          finalVideoUrl = match.group(1);
          print('Success: Found video_url in page JSON.');
        }
      }

      // Check 3: video_versions (Robust Fallback)
      if (finalVideoUrl == null) {
        final vVersionsMatch = RegExp(
          r'"video_versions"\s*:\s*\[(.*?)\]',
        ).firstMatch(body);
        if (vVersionsMatch != null) {
          final vVersionsContent = vVersionsMatch.group(1)!;
          final urlMatch = RegExp(
            r'"url"\s*:\s*"(.*?)"',
          ).firstMatch(vVersionsContent);
          if (urlMatch != null) {
            finalVideoUrl = urlMatch.group(1);
            print('Success: Found video_url in video_versions.');
          }
        }
      }
    } else {
      print('Main Page returned status: ${response.statusCode}');
    }
  } catch (e) {
    print('Error in Main Page strategy: $e');
  }

  // ==============================================================================
  // Strategy 2: Embed URL
  // ==============================================================================
  if (finalVideoUrl == null) {
    print('\n[2] Strategy: Embed URL...');
    final embedUrl = 'https://www.instagram.com/reel/$targetShortcode/embed';
    try {
      final embedHeaders = Map<String, String>.from(headers);
      embedHeaders.remove('Cookie');

      final response = await client.get(
        Uri.parse(embedUrl),
        headers: embedHeaders,
      );
      if (response.statusCode == 200) {
        final body = response.body;
        await File('debug_embed.html').writeAsString(body);

        RegExp regex = RegExp(r'\\"video_url\\"\s*:\s*\\"(.*?)\\"');
        var match = regex.firstMatch(body);
        if (match != null) {
          finalVideoUrl = match.group(1);
          print('Success: Found video_url in Embed HTML.');
        }
      }
    } catch (e) {
      print('Error in Embed strategy: $e');
    }
  }

  // ==============================================================================
  // Strategy 3: JSON API (?__a=1)
  // ==============================================================================
  if (finalVideoUrl == null) {
    print('\n[3] Strategy: JSON API (?__a=1)...');
    final jsonUrl =
        'https://www.instagram.com/p/$targetShortcode/?__a=1&__d=dis';

    try {
      final jsonHeaders = Map<String, String>.from(headers);
      jsonHeaders['Accept'] = 'application/json';

      final response = await client.get(
        Uri.parse(jsonUrl),
        headers: jsonHeaders,
      );

      if (response.statusCode == 200) {
        await File('debug_json_api.json').writeAsString(response.body);
        try {
          final json = jsonDecode(response.body);
          if (json['graphql']?['shortcode_media']?['video_url'] != null) {
            finalVideoUrl = json['graphql']['shortcode_media']['video_url'];
            print('Success: Found video_url in JSON API (graphql).');
          } else if (json['items'] != null && json['items'].isNotEmpty) {
            if (json['items'][0]['video_versions'] != null) {
              finalVideoUrl = json['items'][0]['video_versions'][0]['url'];
              print('Success: Found video_url in JSON API (items).');
            }
          }
        } catch (e) {
          print('JSON Decode Error: $e');
        }
      } else {
        print('JSON API returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error in JSON strategy: $e');
    }
  }

  // ==============================================================================
  // Final Result / Download
  // ==============================================================================

  if (finalVideoUrl != null) {
    finalVideoUrl = finalVideoUrl
        .replaceAll(r'\u0026', '&')
        .replaceAll(r'\/', '/') // Handle single escaped (common in JSON)
        .replaceAll(r'\\/', '/'); // Handle double escaped (safe fallback)

    print('\n[SUCCESS] Video Link Extracted: $finalVideoUrl');
    print('Downloading...');

    try {
      print('Starting request to: $finalVideoUrl');
      // Use authenticated client for download
      final videoResponse = await client.get(
        Uri.parse(finalVideoUrl),
        headers: headers,
      );
      print('Response received (Status: ${videoResponse.statusCode})');

      if (videoResponse.statusCode == 200) {
        final filename = 'insta_$targetShortcode.mp4';
        print('Writing to file: $filename');
        await File(filename).writeAsBytes(videoResponse.bodyBytes);
        print('Video saved to $filename');
      } else {
        print(
          'Download failed (Status ${videoResponse.statusCode}). Link might have expired or requires cookies.',
        );
      }
    } catch (e) {
      print('Download error: $e');
    }
  } else {
    print('\n[FAILURE] Extraction failed.');
    print(
      'Debug files created: debug_main_page.html, debug_embed.html, debug_json_api.json',
    );
  }

  client.close();
  print('Done.');
}
