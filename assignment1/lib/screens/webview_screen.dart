import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class WebViewScreen extends StatefulWidget {
  final String username;
  final bool isDarkMode;
  final SharedPreferences prefs;

  const WebViewScreen({
    super.key,
    required this.username,
    required this.isDarkMode,
    required this.prefs,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Timer? _connectionCheckTimer;
  bool _isLowConnectivity = false;
  int _loadStartTimestamp = 0;
  int _loadTimeoutMs = 15000; // 15 seconds timeout
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadLocalHtmlFile();
    _setupConnectivityTimer();
  }

  void _checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isLowConnectivity = connectivityResult == ConnectivityResult.mobile ||
          connectivityResult == ConnectivityResult.none;
    });
  }

  void _setupConnectivityTimer() {
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkConnectivity();

      // Check if page is still loading after timeout
      if (_isLoading &&
          _loadStartTimestamp > 0 &&
          DateTime.now().millisecondsSinceEpoch - _loadStartTimestamp >
              _loadTimeoutMs) {
        setState(() {
          _hasError = true;
          _isLoading = false;
          _errorMessage =
              'Loading timed out. Please check your internet connection.';
        });
      }
    });
  }

  // Load HTML from assets and save to temporary file
  Future<void> _loadLocalHtmlFile() async {
    try {
      // Get the HTML content from assets
      final String htmlContent =
          await rootBundle.loadString('assets/local_react_app.html');

      // Get the documents directory
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/local_react_app.html';

      // Write the HTML content to a file
      final file = File(filePath);
      await file.writeAsString(htmlContent);

      setState(() {
        _localFilePath = filePath;
      });

      // Initialize WebView after file is ready
      _initWebView();
    } catch (e) {
      setState(() {
        _hasError = true;
        _isLoading = false;
        _errorMessage = 'Failed to load local HTML file: $e';
      });
    }
  }

  void _initWebView() {
    if (_localFilePath == null) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Local HTML file path is not available';
      });
      return;
    }

    _loadStartTimestamp = DateTime.now().millisecondsSinceEpoch;

    // Convert file path to URI
    final fileUri = Uri.file(_localFilePath!).toString();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
              _loadStartTimestamp = DateTime.now().millisecondsSinceEpoch;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _injectUserData();
          },
          onWebResourceError: (WebResourceError error) {
            setState(() {
              _hasError = true;
              _isLoading = false;
              _errorMessage = 'Failed to load page: ${error.description}';
            });
          },
          onNavigationRequest: (NavigationRequest request) {
            // Allow navigation to CDNs and local files
            if (request.url.startsWith('file://') ||
                request.url.contains('unpkg.com') ||
                request.url.contains('cdnjs.cloudflare.com')) {
              return NavigationDecision.navigate;
            }
            // Block navigation to external sites
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadFlutterAsset("assets/local_react_app.html")
      ..addJavaScriptChannel(
        'FlutterChannel',
        onMessageReceived: (JavaScriptMessage message) {
          _handleJavaScriptMessage(message);
        },
      );
  }

  void _handleJavaScriptMessage(JavaScriptMessage message) {
    try {
      final data = jsonDecode(message.message);

      if (data['action'] == 'showAlert' && data['message'] != null) {
        _showAlert(data['message']);
      } else if (data['action'] == 'updateUserData' &&
          data['userData'] != null) {
        _updateUserData(data['userData']);
      } else if (data['action'] == 'logEvent' && data['event'] != null) {
        debugPrint('Event from React: ${data['event']}');
      }
    } catch (e) {
      debugPrint('Error parsing message from JavaScript: $e');
    }
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Message from React'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  void _updateUserData(Map<String, dynamic> userData) async {
    if (userData['username'] != null) {
      await widget.prefs.setString('username', userData['username']);
    }
    if (userData['darkMode'] != null) {
      await widget.prefs.setBool('darkMode', userData['darkMode']);
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User data updated from React app')),
    );
  }

  void _injectUserData() {
    final userData = jsonEncode({
      'username': widget.username,
      'isDarkMode': widget.isDarkMode,
    });

    _controller.runJavaScript('''
      try {
        if (window.receiveDataFromFlutter) {
          window.receiveDataFromFlutter($userData);
        } else {
          // Store data for later use if the function isn't ready yet
          window.flutterUserData = $userData;
          console.log('Stored data from Flutter for later use');
        }
      } catch (e) {
        console.error('Error receiving data from Flutter:', e);
      }
    ''');
  }

  void _sendMessageToReact() {
    final timestamp = DateTime.now().toIso8601String();
    final message = jsonEncode({
      'username': widget.username,
      'isDarkMode': widget.isDarkMode,
      'timestamp': timestamp,
    });

    _controller.runJavaScript('''
      try {
        if (window.receiveDataFromFlutter) {
          window.receiveDataFromFlutter($message);
          console.log('Sent message to React app');
        } else {
          console.warn('React app not ready to receive messages');
        }
      } catch (e) {
        console.error('Error sending message to React:', e);
      }
    ''');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message sent to React app')),
    );
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('React WebView'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Stack(
        children: [
          if (_hasError)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _hasError = false;
                        _isLoading = true;
                      });
                      _loadLocalHtmlFile();
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else if (_localFilePath != null)
            WebViewWidget(controller: _controller)
          else
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_isLoading && _localFilePath != null)
            Container(
              color: Colors.white70,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          if (_isLowConnectivity && !_hasError)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.amber.shade100,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: const Row(
                  children: [
                    Icon(Icons.signal_cellular_alt_1_bar, color: Colors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Low network connectivity detected. Page may load slowly.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _sendMessageToReact,
        child: const Icon(Icons.send),
        tooltip: 'Send data to React',
      ),
    );
  }
}
