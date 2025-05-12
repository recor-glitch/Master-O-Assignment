import 'package:client/services/api_services.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Car Racing Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const CarRacingGame(),
    );
  }
}

class CarRacingGame extends StatefulWidget {
  const CarRacingGame({Key? key}) : super(key: key);

  @override
  State<CarRacingGame> createState() => _CarRacingGameState();
}

class _CarRacingGameState extends State<CarRacingGame> {
  // Game state variables
  double carPositionX = 0.5; // Position from 0.0 to 1.0 (center of screen)
  double score = 0;
  int gameTime = 0;
  bool isGameRunning = false;
  Timer? gameTimer;
  List<RoadSegment> roadSegments = [];

  // API integration variables
  int? sessionId;
  String playerName = "Player"; // Default player name
  bool isLoading = false;
  bool showNameInput = false;
  final TextEditingController playerNameController = TextEditingController();

  // Game settings
  final double roadWidth = 0.6; // Road width as percentage of screen width
  final double carWidth = 60;
  final double carHeight = 100;
  final double moveSpeed = 0.05; // How much car moves when button pressed
  final int maxSegments = 10; // Max number of road segments visible

  @override
  void initState() {
    super.initState();
    // Initialize road with straight segments
    for (int i = 0; i < maxSegments; i++) {
      roadSegments.add(RoadSegment(
        offset: 0.0, // Straight road to start
        y: i.toDouble(),
      ));
    }
    playerNameController.text = playerName;
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    playerNameController.dispose();
    super.dispose();
  }

  Future<void> startGame() async {
    if (isGameRunning || isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // Create a new game session
      Map<String, dynamic> deviceInfo = {
        'platform': 'Flutter',
        'screenWidth': MediaQuery.of(context).size.width,
        'screenHeight': MediaQuery.of(context).size.height,
      };

      final sessionData = await ApiService.saveGameSession(
        id: sessionId,
        playerName: playerName,
        score: 0,
        timePlayed: 0,
        deviceInfo: deviceInfo,
      );

      setState(() {
        isGameRunning = true;
        isLoading = false;
        score = 0;
        gameTime = 0;
        carPositionX = 0.5;
        sessionId = sessionData['sessionId'];

        // Reset road
        roadSegments.clear();
        for (int i = 0; i < maxSegments; i++) {
          roadSegments.add(RoadSegment(
            offset: 0.0,
            y: i.toDouble(),
          ));
        }
      });

      // Start game loop
      gameTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
        updateGame();
      });

      // Record game start action
      if (sessionId != null) {
        ApiService.saveGameAction(
          sessionId: sessionId!,
          actionType: 'START',
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: Text('Could not connect to the server: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> endGame() async {
    if (!isGameRunning) return;

    // First stop the game timer and update state
    gameTimer?.cancel();
    gameTimer = null;

    setState(() {
      isGameRunning = false;
      isLoading = true;
    });

    try {
      // Update game session with final score and time
      if (sessionId != null) {
        // Record game end action
        await ApiService.saveGameAction(
          sessionId: sessionId!,
          actionType: 'FINISH',
        );

        // Then update the game session with final data
        await ApiService.saveGameSession(
          id: sessionId,
          playerName: playerName,
          score: score.toInt(),
          timePlayed: gameTime,
          deviceInfo: null, // We already sent this info
        );
      }
    } catch (e) {
      print('Error updating game session: $e');

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: Text('Could not save game results: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void updateGame() {
    if (!isGameRunning) return;

    setState(() {
      // Increase score and time
      score += 1;
      gameTime += 50; // 50ms per update

      // Move road segments up
      for (int i = 0; i < roadSegments.length; i++) {
        roadSegments[i] = RoadSegment(
          offset: roadSegments[i].offset,
          y: roadSegments[i].y - 0.1, // Speed of road movement
        );
      }

      // Remove segments that are off-screen
      roadSegments.removeWhere((segment) => segment.y < 0);

      // Add new segments at the bottom
      while (roadSegments.length < maxSegments) {
        // Get the last segment
        final lastSegment = roadSegments.last;

        // Create a new segment with slightly different offset
        double newOffset =
            lastSegment.offset + (math.Random().nextDouble() - 0.5) * 0.1;
        // Limit the maximum road curvature
        newOffset = newOffset.clamp(-0.3, 0.3);

        roadSegments.add(RoadSegment(
          offset: newOffset,
          y: lastSegment.y + 1.0,
        ));
      }

      // Check if car is on the road
      final currentSegment = roadSegments.firstWhere(
        (segment) => segment.y >= 1.0 && segment.y < 2.0,
        orElse: () => roadSegments.first,
      );

      final roadLeftEdge = 0.5 - roadWidth / 2 + currentSegment.offset;
      final roadRightEdge = 0.5 + roadWidth / 2 + currentSegment.offset;

      // Car is considered as a point for simplicity
      if (carPositionX < roadLeftEdge || carPositionX > roadRightEdge) {
        // Car is off the road - game over
        endGame();
      }
    });
  }

  Future<void> moveCarLeft() async {
    if (!isGameRunning) return;
    setState(() {
      carPositionX = (carPositionX - moveSpeed).clamp(0.0, 1.0);
    });

    // Track movement action
    if (sessionId != null) {
      ApiService.saveGameAction(
        sessionId: sessionId!,
        actionType: 'MOVE_LEFT',
      );
    }
  }

  Future<void> moveCarRight() async {
    if (!isGameRunning) return;
    setState(() {
      carPositionX = (carPositionX + moveSpeed).clamp(0.0, 1.0);
    });

    // Track movement action
    if (sessionId != null) {
      ApiService.saveGameAction(
        sessionId: sessionId!,
        actionType: 'MOVE_RIGHT',
      );
    }
  }

  void toggleNameInput() {
    setState(() {
      showNameInput = !showNameInput;
    });
  }

  void setPlayerName(String name) {
    if (name.trim().isNotEmpty) {
      setState(() {
        playerName = name.trim();
        showNameInput = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Car Racing Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              // Show leaderboard
              showLeaderboard();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Score display
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Score: ${score.toInt()}',
                    style: const TextStyle(fontSize: 24)),
                Text('Time: ${(gameTime / 1000).toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 24)),
              ],
            ),
          ),

          // Game area
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16, // Portrait mode for mobile
                child: Container(
                  color: Colors.green, // Background is grass
                  child: Stack(
                    children: [
                      // Draw road segments
                      ...roadSegments.map((segment) => Positioned(
                            left: 0,
                            right: 0,
                            top: MediaQuery.of(context).size.height *
                                (segment.y / maxSegments),
                            height: MediaQuery.of(context).size.height /
                                maxSegments,
                            child: CustomPaint(
                              painter: RoadPainter(
                                roadWidth: roadWidth,
                                offset: segment.offset,
                              ),
                              child: Container(),
                            ),
                          )),

                      // Draw car
                      Positioned(
                        left: MediaQuery.of(context).size.width * carPositionX -
                            carWidth / 2,
                        bottom: 100,
                        width: carWidth,
                        height: carHeight,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.lightBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Container(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Game start/over overlay
                      if (!isGameRunning)
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'Car Racing Game',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                if (score > 0)
                                  Text(
                                    'Game Over!\nScore: ${score.toInt()}\nTime: ${(gameTime / 1000).toStringAsFixed(1)}s',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                const SizedBox(height: 10),

                                // Player name display/input
                                if (showNameInput)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: TextField(
                                      controller: playerNameController,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: const InputDecoration(
                                        labelText: 'Your Name',
                                        labelStyle:
                                            TextStyle(color: Colors.white70),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.white54),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide:
                                              BorderSide(color: Colors.blue),
                                        ),
                                      ),
                                      onSubmitted: (value) {
                                        setPlayerName(value);
                                      },
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Player: $playerName',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          color: Colors.white,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit,
                                            color: Colors.white),
                                        onPressed: toggleNameInput,
                                      ),
                                    ],
                                  ),

                                const SizedBox(height: 20),
                                ElevatedButton(
                                  onPressed: isLoading ? null : startGame,
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 40, vertical: 15),
                                  ),
                                  child: isLoading
                                      ? const CircularProgressIndicator()
                                      : const Text(
                                          'Start Game',
                                          style: TextStyle(fontSize: 20),
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Control buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: moveCarLeft,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.arrow_left, size: 50),
                ),
                ElevatedButton(
                  onPressed: moveCarRight,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(20),
                    shape: const CircleBorder(),
                  ),
                  child: const Icon(Icons.arrow_right, size: 50),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> showLeaderboard() async {
    setState(() {
      isLoading = true;
    });

    try {
      final sessions = await ApiService.getGameSessions();

      // Sort by score (highest first)
      sessions.sort((a, b) => b['score'].compareTo(a['score']));

      // Take top 10
      final topSessions = sessions.take(10).toList();

      setState(() {
        isLoading = false;
      });

      // Show leaderboard
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Leaderboard'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: topSessions.length,
              itemBuilder: (context, index) {
                final session = topSessions[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(session['playerName'] ?? 'Unknown'),
                  subtitle: Text(
                      'Time: ${(session['timePlayed'] / 1000).toStringAsFixed(1)}s'),
                  trailing: Text('${session['score']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      // Show error dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: Text('Could not load leaderboard: $e'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }
}

class RoadSegment {
  final double offset; // Road offset from center
  final double y; // Position on screen (0 = top, maxSegments = bottom)

  RoadSegment({required this.offset, required this.y});
}

class RoadPainter extends CustomPainter {
  final double roadWidth;
  final double offset;

  RoadPainter({required this.roadWidth, required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey
      ..style = PaintingStyle.fill;

    // Draw road with offset
    final centerX = size.width / 2 + (size.width * offset);
    final roadLeft = centerX - (size.width * roadWidth / 2);
    final roadRight = centerX + (size.width * roadWidth / 2);

    final roadPath = Path()
      ..moveTo(roadLeft, 0)
      ..lineTo(roadRight, 0)
      ..lineTo(roadRight, size.height)
      ..lineTo(roadLeft, size.height)
      ..close();

    canvas.drawPath(roadPath, paint);

    // Draw road markings
    final linePaint = Paint()
      ..color = Colors.yellow
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    // Center line
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
