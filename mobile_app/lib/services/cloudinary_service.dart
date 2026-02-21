import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Free Cloudinary upload service — replaces Firebase Storage.
///
/// Setup:
///   1. Create a free account at https://cloudinary.com
///   2. Go to Settings → Upload → Add upload preset → Signing Mode: Unsigned
///   3. Fill in [cloudName] and [uploadPreset] below.
class CloudinaryService {
  // ── FILL THESE IN from your Cloudinary Dashboard / Settings ──
  static const String cloudName = 'dqzzhefov';       // e.g. 'dxyz1234abc'
  static const String uploadPreset = 'proxy-social';  // e.g. 'proxi_unsigned'

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
    final ext = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(ext);
    final isPdf = ext == '.pdf';

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
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString();
      throw Exception('Cloudinary upload failed (${ response.statusCode}): $body');
    }

    final json = jsonDecode(await response.stream.bytesToString());
    return json['secure_url'] as String;
  }
}
