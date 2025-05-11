import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class WebViewUtils {
  // Load the local HTML file and return its URI
  static Future<String> getLocalHtmlUri() async {
    try {
      // Read the asset file
      final String htmlContent =
          await rootBundle.loadString('assets/local_react_app.html');

      // Get temporary directory to store the file
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = tempDir.path;

      // Create the file in the temporary directory
      final File file = File('$tempPath/local_react_app.html');
      await file.writeAsString(htmlContent);

      // Return the URI
      return 'file://${file.path}';
    } catch (e) {
      print('Error loading local HTML file: $e');
      return 'about:blank';
    }
  }
}
