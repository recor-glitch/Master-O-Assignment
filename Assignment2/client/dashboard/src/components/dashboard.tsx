import React, { useState, useEffect } from "react";
import { Bar, Line, Pie } from "react-chartjs-2";
import "./dashboard.css";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  PointElement,
  LineElement,
  ArcElement,
  Title,
  Tooltip,
  Legend
);

// Type definitions
type GameSession = {
  id: number;
  player_name: string;
  score: number;
  time_played_ms: number;
  completed_at: string;
  device_info?: string;
};

type TopScore = {
  id: number;
  player_name: string;
  score: number;
};

type GamesPerDay = {
  date: string;
  count: number;
};

type DashboardStats = {
  totalGames: number;
  avgScore: number;
  avgTimeMs: number;
  avgTimeSeconds: number;
  topScores: TopScore[];
  gamesPerDay: GamesPerDay[];
};

const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [sessions, setSessions] = useState<GameSession[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [error, setError] = useState<string | null>(null);

  const baseUrl = "http://localhost:3000/api";

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [statsRes, sessionsRes] = await Promise.all([
          fetch(`${baseUrl}/statistics`),
          fetch(`${baseUrl}/game-sessions`),
        ]);

        if (!statsRes.ok || !sessionsRes.ok) {
          throw new Error("Failed to fetch data");
        }

        const statsData: DashboardStats = await statsRes.json();
        const sessionsData: GameSession[] = await sessionsRes.json();

        setStats(statsData);
        setSessions(sessionsData);
        setLoading(false);
      } catch (err) {
        setError(
          err instanceof Error ? err.message : "An unknown error occurred"
        );
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  if (loading) return <div className="loading">Loading dashboard...</div>;
  if (error) return <div className="error">Error: {error}</div>;
  if (!stats) return <div className="error">No data available</div>;

  return (
    <div className="dashboard">
      <h1>Car Game Analytics Dashboard</h1>

      <div className="summary-cards">
        <div className="card">
          <h3>Total Games</h3>
          <p>{stats.totalGames}</p>
        </div>
        <div className="card">
          <h3>Average Score</h3>
          <p>{Math.round(stats.avgScore)}</p>
        </div>
        <div className="card">
          <h3>Avg Play Time</h3>
          <p>{stats.avgTimeSeconds} sec</p>
        </div>
      </div>

      <div className="chart-row">
        <div className="chart-container">
          <h2>Top Scores</h2>
          <TopScoresChart data={stats.topScores} />
        </div>
        <div className="chart-container">
          <h2>Games Per Day (Last 7 Days)</h2>
          <GamesPerDayChart data={stats.gamesPerDay} />
        </div>
      </div>

      <div className="chart-row">
        <div className="chart-container">
          <h2>Score Distribution</h2>
          <ScoreDistributionChart sessions={sessions} />
        </div>
        <div className="chart-container">
          <h2>Recent Sessions</h2>
          <RecentSessionsTable sessions={sessions.slice(0, 5)} />
        </div>
      </div>
    </div>
  );
};

type TopScoresChartProps = {
  data: TopScore[];
};

const TopScoresChart: React.FC<TopScoresChartProps> = ({ data }) => {
  const chartData = {
    labels: data.map((item) => item.player_name),
    datasets: [
      {
        label: "Score",
        data: data.map((item) => item.score),
        backgroundColor: "rgba(54, 162, 235, 0.6)",
        borderColor: "rgba(54, 162, 235, 1)",
        borderWidth: 1,
      },
    ],
  };

  const options = {
    responsive: true,
    plugins: {
      legend: {
        display: false,
      },
    },
    scales: {
      y: {
        beginAtZero: true,
      },
    },
  };

  return <Bar data={chartData} options={options} />;
};

type GamesPerDayChartProps = {
  data: GamesPerDay[];
};

const GamesPerDayChart: React.FC<GamesPerDayChartProps> = ({ data }) => {
  // Fill in missing days with 0
  const last7Days = Array.from({ length: 7 }, (_, i) => {
    const date = new Date();
    date.setDate(date.getDate() - (6 - i));
    return date.toISOString().split("T")[0];
  });

  const chartData = {
    labels: last7Days,
    datasets: [
      {
        label: "Games Played",
        data: last7Days.map((day) => {
          const dayData = data.find((d) => d.date === day);
          return dayData ? dayData.count : 0;
        }),
        borderColor: "rgba(75, 192, 192, 1)",
        backgroundColor: "rgba(75, 192, 192, 0.2)",
        tension: 0.1,
        fill: true,
      },
    ],
  };

  const options = {
    responsive: true,
    plugins: {
      legend: {
        display: false,
      },
    },
    scales: {
      y: {
        beginAtZero: true,
      },
    },
  };

  return <Line data={chartData} options={options} />;
};

type ScoreDistributionChartProps = {
  sessions: GameSession[];
};

const ScoreDistributionChart: React.FC<ScoreDistributionChartProps> = ({
  sessions,
}) => {
  // Categorize scores into ranges
  const scoreRanges = {
    "0-100": 0,
    "101-200": 0,
    "201-300": 0,
    "301-400": 0,
    "401-500": 0,
    "501+": 0,
  };

  sessions.forEach((session) => {
    const score = session.score;
    if (score <= 100) scoreRanges["0-100"]++;
    else if (score <= 200) scoreRanges["101-200"]++;
    else if (score <= 300) scoreRanges["201-300"]++;
    else if (score <= 400) scoreRanges["301-400"]++;
    else if (score <= 500) scoreRanges["401-500"]++;
    else scoreRanges["501+"]++;
  });

  const chartData = {
    labels: Object.keys(scoreRanges),
    datasets: [
      {
        data: Object.values(scoreRanges),
        backgroundColor: [
          "rgba(255, 99, 132, 0.6)",
          "rgba(54, 162, 235, 0.6)",
          "rgba(255, 206, 86, 0.6)",
          "rgba(75, 192, 192, 0.6)",
          "rgba(153, 102, 255, 0.6)",
          "rgba(255, 159, 64, 0.6)",
        ],
        borderColor: [
          "rgba(255, 99, 132, 1)",
          "rgba(54, 162, 235, 1)",
          "rgba(255, 206, 86, 1)",
          "rgba(75, 192, 192, 1)",
          "rgba(153, 102, 255, 1)",
          "rgba(255, 159, 64, 1)",
        ],
        borderWidth: 1,
      },
    ],
  };

  return <Pie data={chartData} />;
};

type RecentSessionsTableProps = {
  sessions: GameSession[];
};

const RecentSessionsTable: React.FC<RecentSessionsTableProps> = ({
  sessions,
}) => {
  return (
    <div className="sessions-table">
      <table>
        <thead>
          <tr>
            <th>Player</th>
            <th>Score</th>
            <th>Time (s)</th>
            <th>Date</th>
          </tr>
        </thead>
        <tbody>
          {sessions.map((session) => (
            <tr key={session.id}>
              <td>{session.player_name}</td>
              <td>{session.score}</td>
              <td>{Math.round(session.time_played_ms / 1000)}</td>
              <td>{new Date(session.completed_at).toLocaleDateString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
};

export default Dashboard;
