import 'package:comapp/screens/webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  final SharedPreferences prefs;

  const HomeScreen({super.key, required this.prefs});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _reactAppUrlController = TextEditingController();
  String _username = '';
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Default React demo app URL
    _reactAppUrlController.text = 'https://reactjs.org/';
  }

  _loadUserData() {
    setState(() {
      _username = widget.prefs.getString('username') ?? '';
      _isDarkMode = widget.prefs.getBool('darkMode') ?? false;
      _usernameController.text = _username;
    });
  }

  _saveUserData() async {
    setState(() {
      _username = _usernameController.text;
    });
    await widget.prefs.setString('username', _username);
    await widget.prefs.setBool('darkMode', _isDarkMode);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User preferences saved')),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _reactAppUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter React Integration'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'User Preferences',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reactAppUrlController,
              decoration: const InputDecoration(
                labelText: 'React App URL',
                border: OutlineInputBorder(),
                hintText: 'https://example.com',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saveUserData,
              child: const Text('Save Preferences'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(
                      username: _username,
                      isDarkMode: _isDarkMode,
                      prefs: widget.prefs,
                    ),
                  ),
                );
              },
              child: const Text('Open React WebView'),
            ),
            const Spacer(),
            const Center(
              child: Text(
                'MERN + Flutter Assignment',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
