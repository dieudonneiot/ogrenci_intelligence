import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<void> downloadCsv(String csv, String fileName) async {
  final bytes = Uint8List.fromList(utf8.encode(csv));
  final blobParts = [bytes].jsify() as JSArray<web.BlobPart>;
  final blob = web.Blob(
    blobParts,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
