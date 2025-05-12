import cors from "cors";
import express from "express";

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.static("public"));
app.use(express.json());

import { createPool } from "mysql2/promise";

const pool = createPool({
  host: process.env.HOST,
  user: process.env.USER,
  password: process.env.PASSWORD,
  database: process.env.DATABASE,
  port: process.env.PORT,
  // host: "mysql",
  // user: "appuser",
  // password: "userpassword",
  // database: "car_game_db",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

const initializeDatabase = async () => {
  try {
    // Create tables if they don't exist
    await pool.query(`
      CREATE TABLE IF NOT EXISTS game_sessions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        player_name VARCHAR(255) DEFAULT 'Anonymous',
        score INT NOT NULL,
        time_played_ms INT NOT NULL,
        completed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        device_info TEXT
      )
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS game_actions (
        id INT AUTO_INCREMENT PRIMARY KEY,
        session_id INT,
        action_type ENUM('START', 'MOVE_LEFT', 'MOVE_RIGHT', 'CRASH', 'FINISH'),
        timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (session_id) REFERENCES game_sessions(id)
      )
    `);

    console.log("Database initialized successfully");
  } catch (error) {
    console.error("Error initializing database:", error);
  }
};

app.post("/api/game-sessions", async (req, res) => {
  try {
    const { id, playerName, score, timePlayed, deviceInfo } = req.body;

    if (!id) {
      const [result] = await pool.query(
        "INSERT INTO game_sessions (player_name, score, time_played_ms, device_info) VALUES (?, ?, ?, ?)",
        [
          playerName || "Anonymous",
          score,
          timePlayed,
          JSON.stringify(deviceInfo),
        ]
      );

      res.status(201).json({
        success: true,
        sessionId: result.insertId,
      });
      return;
    }
    // Update existing session
    await pool.query(
      "UPDATE game_sessions SET player_name = ?, score = ?, time_played_ms = ?, device_info = ? WHERE id = ?",
      [
        playerName || "Anonymous",
        score,
        timePlayed,
        JSON.stringify(deviceInfo),
        id,
      ]
    );

    res.status(200).json({ success: true });
  } catch (error) {
    console.error("Error recording game action:", error);
    res
      .status(500)
      .json({ success: false, error: "Failed to record game action" });
  }
});

app.post("/api/game-actions", async (req, res) => {
  try {
    const { sessionId, actionType } = req.body;

    await pool.query(
      "INSERT INTO game_actions (session_id, action_type) VALUES (?, ?)",
      [sessionId, actionType]
    );

    res.status(201).json({ success: true });
  } catch (error) {
    console.error("Error recording game action:", error);
    res
      .status(500)
      .json({ success: false, error: "Failed to record game action" });
  }
});

app.get("/api/game-sessions", async (req, res) => {
  try {
    const [rows] = await pool.query(
      "SELECT * FROM game_sessions ORDER BY completed_at DESC"
    );
    res.json(rows);
  } catch (error) {
    console.error("Error fetching game sessions:", error);
    res
      .status(500)
      .json({ success: false, error: "Failed to fetch game sessions" });
  }
});

app.get("/api/statistics", async (req, res) => {
  try {
    // Total number of games
    const [totalGamesResult] = await pool.query(
      "SELECT COUNT(*) as total FROM game_sessions"
    );
    const totalGames = totalGamesResult[0].total;

    // Average score
    const [avgScoreResult] = await pool.query(
      "SELECT AVG(score) as average FROM game_sessions"
    );
    const avgScore = avgScoreResult[0].average || 0;

    // Average play time
    const [avgTimeResult] = await pool.query(
      "SELECT AVG(time_played_ms) as average FROM game_sessions"
    );
    const avgTimeMs = avgTimeResult[0].average || 0;

    // Top 5 scores
    const [topScores] = await pool.query(
      "SELECT id, player_name, score FROM game_sessions ORDER BY score DESC LIMIT 5"
    );

    // Games per day (last 7 days)
    const [gamesPerDay] = await pool.query(`
      SELECT 
        DATE(completed_at) as date, 
        COUNT(*) as count 
      FROM game_sessions 
      WHERE completed_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)
      GROUP BY DATE(completed_at)
      ORDER BY date
    `);

    res.json({
      totalGames,
      avgScore,
      avgTimeMs,
      avgTimeSeconds: Math.round(avgTimeMs / 1000),
      topScores,
      gamesPerDay,
    });
  } catch (error) {
    console.error("Error fetching statistics:", error);
    res
      .status(500)
      .json({ success: false, error: "Failed to fetch statistics" });
  }
});

app.post("/api/reports/csv", async (req, res) => {
  try {
    const { metrics, dateRange } = req.body;

    // Build query based on selected metrics
    let selectClauses = [];
    let fromClause = "FROM game_sessions gs";
    let whereClause = "";

    // Handle date range filter
    if (dateRange && dateRange.start && dateRange.end) {
      whereClause = `WHERE gs.completed_at BETWEEN '${dateRange.start}' AND '${dateRange.end}'`;
    }

    // Process each metric
    metrics.forEach((metric) => {
      switch (metric) {
        case "id":
          selectClauses.push('gs.id as "Master-O ID"');
          break;
        case "score":
          selectClauses.push('gs.score as "Score"');
          break;
        case "time_played":
          selectClauses.push('gs.time_played_ms as "Time Spent (ms)"');
          selectClauses.push(
            '(gs.time_played_ms / 1000) as "Time Spent (seconds)"'
          );
          break;
        case "completed_at":
          selectClauses.push('gs.completed_at as "Completion Date"');
          break;
        case "player_name":
          selectClauses.push('gs.player_name as "Player Name"');
          break;
        // Add more metrics as needed
      }
    });

    // If no metrics selected, return error
    if (selectClauses.length === 0) {
      return res
        .status(400)
        .json({ success: false, error: "No metrics selected" });
    }

    // Build and execute query
    const query = `SELECT ${selectClauses.join(
      ", "
    )} ${fromClause} ${whereClause}`;
    const [rows] = await pool.query(query);

    // Convert to CSV
    const parser = new Parser();
    const csv = parser.parse(rows);

    // Generate filename
    const timestamp = moment().format("YYYY-MM-DD_HH-mm-ss");
    const filename = `game_report_${timestamp}.csv`;

    // Save CSV file
    const filePath = join(__dirname, "public", "reports", filename);

    // Ensure directory exists
    if (!existsSync(join(__dirname, "public", "reports"))) {
      mkdirSync(join(__dirname, "public", "reports"), {
        recursive: true,
      });
    }

    writeFileSync(filePath, csv);

    // Return download URL
    res.json({
      success: true,
      downloadUrl: `/reports/${filename}`,
    });
  } catch (error) {
    console.error("Error generating CSV report:", error);
    res
      .status(500)
      .json({ success: false, error: "Failed to generate CSV report" });
  }
});

app.listen(PORT, async () => {
  console.log(`Server running on port ${PORT}`);
  await initializeDatabase();
});
