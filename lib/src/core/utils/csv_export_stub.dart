import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';

Future<void> downloadCsv(String csv, String fileName) async {
  final location = await getSaveLocation(suggestedName: fileName);
  if (location == null) return;
  final file = File(location.path);
  await file.writeAsBytes(utf8.encode(csv), flush: true);
}
