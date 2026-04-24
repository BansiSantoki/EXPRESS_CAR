import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String _imgbbApiKey = String.fromEnvironment('IMGBB_API_KEY');

class ImgbbUploadException implements Exception {
  ImgbbUploadException(this.message);

  final String message;

  @override
  String toString() => 'ImgbbUploadException: $message';
}

Future<String> uploadFileToImgbb(File file, {String? fileName}) async {
  final bytes = await file.readAsBytes();
  final name = fileName ?? file.path.split(RegExp(r'[\\/]')).last;
  return uploadBytesToImgbb(bytes, fileName: name);
}

Future<String> uploadAssetToImgbb(String assetPath, {String? fileName}) async {
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final name = fileName ?? assetPath.split('/').last;
  return uploadBytesToImgbb(bytes, fileName: name);
}

Future<String> uploadBytesToImgbb(
  List<int> bytes, {
  required String fileName,
}) async {
  if (_imgbbApiKey.trim().isEmpty) {
    throw ImgbbUploadException(
      'IMGBB_API_KEY is not set. Run the app with --dart-define=IMGBB_API_KEY=YOUR_KEY',
    );
  }

  final request = http.MultipartRequest(
    'POST',
    Uri.parse('https://api.imgbb.com/1/upload'),
  );
  request.fields['key'] = _imgbbApiKey;
  request.files.add(
    http.MultipartFile.fromBytes('image', bytes, filename: fileName),
  );

  final streamedResponse = await request.send();
  final response = await http.Response.fromStream(streamedResponse);
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;

  if (response.statusCode < 200 || response.statusCode >= 300) {
    final errorMessage = decoded['error'] is Map<String, dynamic>
        ? decoded['error']['message']?.toString()
        : null;
    throw ImgbbUploadException(
      errorMessage ?? 'ImgBB upload failed with status ${response.statusCode}',
    );
  }

  if (decoded['success'] != true) {
    final errorMessage = decoded['error'] is Map<String, dynamic>
        ? decoded['error']['message']?.toString()
        : null;
    throw ImgbbUploadException(
      errorMessage ?? 'ImgBB upload response did not report success.',
    );
  }

  final data = decoded['data'] as Map<String, dynamic>?;
  final url = data?['url']?.toString() ?? data?['display_url']?.toString();
  if (url == null || url.isEmpty) {
    throw ImgbbUploadException('ImgBB response did not include an image URL.');
  }

  return url;
}
