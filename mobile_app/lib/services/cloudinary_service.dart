import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Free Cloudinary upload service — replaces Firebase Storage.
///
/// Setup:
///   1. Create a free account at https://cloudinary.com
///   2. Go to Settings → Upload → Add upload preset → Signing Mode: Unsigned
///   3. Fill in [cloudName] and [uploadPreset] below.
///   4. For deletion support, also fill in [apiKey] and [apiSecret]
///      from Cloudinary Dashboard → Settings → Access Keys.
class CloudinaryService {
  // ── FILL THESE IN from your Cloudinary Dashboard / Settings ──
  static const String cloudName = '';       // e.g. 'dxyz1234abc'
  static const String uploadPreset = '';  // e.g. 'proxi_unsigned'

  // ── For deletion (Settings → Access Keys) ──
  static const String apiKey = '';      // e.g. '123456789012345'
  static const String apiSecret = '';   // e.g. 'abcDEFghiJKLmno_pqrSTU'

  static const int maxVideoSizeMB = 100; // Cloudinary free-tier limit

  // Cloudinary unsigned-upload endpoints
  static String get _imageUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
  static String get _videoUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/video/upload';
  static String get _rawUploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/raw/upload';

  /// Upload a file and return its public URL.
  ///
  /// [file]   – the local file to upload
  /// [path]   – a logical path like "uploads/uid/avatar.jpg" (used as public_id)
  Future<String> uploadFile(File file, String path) async {
    // Verify file exists and is readable
    if (!await file.exists()) {
      throw Exception('File not found: ${file.path}');
    }

    final fileSizeMB = await file.length() / (1024 * 1024);
    final ext = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
    final isPdf = ext == '.pdf';

    // Check video size
    if (isVideo && fileSizeMB > maxVideoSizeMB) {
      throw Exception(
          'Video too large (${fileSizeMB.toStringAsFixed(1)} MB). '
          'Max allowed: $maxVideoSizeMB MB.');
    }

    final endpoint = isVideo
        ? _videoUploadUrl
        : isPdf
            ? _rawUploadUrl
            : _imageUploadUrl;

    // Strip extension from path for Cloudinary public_id
    final publicId = p.withoutExtension(path);

    final request = http.MultipartRequest('POST', Uri.parse(endpoint))
      ..fields['upload_preset'] = uploadPreset
      ..fields['public_id'] = publicId
      ..fields['resource_type'] = isVideo ? 'video' : isPdf ? 'raw' : 'image'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final http.StreamedResponse response;
    try {
      response = await request.send().timeout(
            Duration(minutes: isVideo ? 5 : 2),
            onTimeout: () => throw Exception(
                'Upload timed out. Check your internet connection.'),
          );
    } catch (e) {
      if (e is Exception &&
          e.toString().contains('Upload timed out')) {
        rethrow;
      }
      throw Exception('Network error during upload: $e');
    }

    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception(
          'Upload failed (${response.statusCode}): $body');
    }

    final json = jsonDecode(body);
    return json['secure_url'] as String;
  }

  /// Extract the Cloudinary public_id from a full Cloudinary URL.
  ///
  /// e.g. "https://res.cloudinary.com/ds9dmq1ob/image/upload/v123/uploads/uid/avatar.jpg"
  ///   → "uploads/uid/avatar"
  static String? extractPublicId(String url) {
    try {
      final uri = Uri.parse(url);
      if (!uri.host.contains('cloudinary.com')) return null;
      // Path: /{cloudName}/{resourceType}/upload/{version?}/{public_id}.{ext}
      final segments = uri.pathSegments; // ['ds9dmq1ob', 'image', 'upload', 'v123', 'uploads', 'uid', 'avatar.jpg']
      final uploadIdx = segments.indexOf('upload');
      if (uploadIdx < 0) return null;
      var remaining = segments.sublist(uploadIdx + 1);
      // Skip version segment (starts with 'v' followed by digits)
      if (remaining.isNotEmpty && RegExp(r'^v\d+$').hasMatch(remaining.first)) {
        remaining = remaining.sublist(1);
      }
      if (remaining.isEmpty) return null;
      final joined = remaining.join('/');
      // Strip file extension
      return p.withoutExtension(joined);
    } catch (_) {
      return null;
    }
  }

  /// Determine the Cloudinary resource_type from a URL ('image', 'video', or 'raw').
  static String _resourceTypeFromUrl(String url) {
    final uri = Uri.parse(url);
    final segments = uri.pathSegments;
    if (segments.length > 1) {
      final rt = segments[1]; // index 0 = cloudName, index 1 = resource_type
      if (rt == 'video' || rt == 'raw') return rt;
    }
    return 'image';
  }

  /// Delete a Cloudinary asset by its full URL.
  ///
  /// Requires [apiKey] and [apiSecret] to be filled in.
  /// Silently skips deletion if credentials are not configured.
  Future<void> deleteFile(String url) async {
    if (apiKey.isEmpty || apiSecret.isEmpty) return; // credentials not set

    final publicId = extractPublicId(url);
    if (publicId == null || publicId.isEmpty) return;

    final resourceType = _resourceTypeFromUrl(url);
    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    // Signature: SHA1("public_id={id}&timestamp={ts}{apiSecret}")
    final toSign = 'public_id=$publicId&timestamp=$timestamp$apiSecret';
    final signature = sha1.convert(utf8.encode(toSign)).toString();

    final endpoint = 'https://api.cloudinary.com/v1_1/$cloudName/$resourceType/destroy';
    try {
      final response = await http.post(
        Uri.parse(endpoint),
        body: {
          'public_id': publicId,
          'api_key': apiKey,
          'timestamp': timestamp,
          'signature': signature,
        },
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        // Non-fatal — log only
        // ignore: avoid_print
        print('[Cloudinary] deleteFile failed (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Cloudinary] deleteFile error: $e');
    }
  }
}
