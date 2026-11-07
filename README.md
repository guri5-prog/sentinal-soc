# Sentinel SOC Platform

A student-built Security Operations Center demonstration. It collects synthetic security events, detects suspicious patterns with rule-based logic and an optional Isolation Forest service, and presents alerts in a React dashboard.

## Features

- REST API for individual and batch event ingestion.
- Rule-based detection mapped to MITRE ATT&CK: repeated failed logins (T1110), unusual UTC activity hours (T1078), and unusually high file access (T1005).
- Optional Python Isolation Forest scoring. If the ML service is disabled or unavailable, rule-based detection continues.
- Risk scoring and LOW / MEDIUM / HIGH alert classification.
- Live alert updates over WebSocket.
- Alert status updates, investigation notes, raw log viewer, admin user/role management, detection rule toggles, and audit trail.
- PostgreSQL persistence with Flyway migrations.

## Technology

| Part | Technology |
|---|---|
| Frontend | React, Vite, Chart.js, STOMP WebSocket client |
| Backend | Spring Boot 3.5, Java 21, Spring Security, JWT, JDBC/JPA |
| Database | PostgreSQL 16 |
| Optional ML service | Python, FastAPI, scikit-learn |
| Simulator | Python script that generates harmless synthetic events |
| Local packaging | Docker Compose |

Redis is not required. Failed-login detection uses a PostgreSQL time-window query and a partial index. This reduces the number of services needed for the free cloud deployment.

## Architecture

```text
Local simulator / log source
          |
          v
    Spring Boot API  -----> Optional Python ML scoring service
       |       |
       |       +----> WebSocket alert broadcasts
       v
  PostgreSQL (events, alerts, users, notes, audit)
       |
       v
   React dashboard
```

For the free cloud deployment, the React app is built as static files on Cloudflare Pages, Spring Boot runs on Render, and PostgreSQL is hosted by Neon. The Python ML service is disabled in the small free backend; all rule-based detections remain enabled.

## Run locally with Docker Compose

Requirements: Docker Desktop with Docker Compose v2.

1. Copy `.env.example` to `.env`.
2. Edit `.env` and set a strong local database password, JWT secret, administrator email, and administrator password.
3. From the project root, run:

   ```powershell
   docker compose up -d --build
   ```

4. Open <http://localhost:5173> and sign in with the administrator credentials from your `.env` file.

Local endpoints:
- Frontend: <http://localhost:5173>
- Backend health: <http://localhost:8080/api/health>
- Optional ML health: <http://localhost:8000/health>

The first backend startup runs Flyway migrations and creates the initial administrator account if the users table is empty.

## Generate synthetic demo events

The simulator sends synthetic events to the local API by default:

```powershell
pip install -r simulator/requirements.txt
python simulator/simulate.py --mode normal --count 20 --email YOUR_ADMIN_EMAIL --password YOUR_ADMIN_PASSWORD
python simulator/simulate.py --mode bruteforce --count 8 --delay 0.5 --email YOUR_ADMIN_EMAIL --password YOUR_ADMIN_PASSWORD
python simulator/simulate.py --mode offhours --count 2 --email YOUR_ADMIN_EMAIL --password YOUR_ADMIN_PASSWORD
python simulator/simulate.py --mode bulk --count 2 --email YOUR_ADMIN_EMAIL --password YOUR_ADMIN_PASSWORD
```

To send to a deployed backend, replace the default URL:

```powershell
python simulator/simulate.py --url https://YOUR-RENDER-URL/api/logs/single --email YOUR_ADMIN_EMAIL --password YOUR_ADMIN_PASSWORD --mode normal --count 10
```

Modes:

| Mode | Expected result |
|---|---|
| `normal` | Events appear in Log Viewer; normally no alert |
| `bruteforce` | Repeated failed-login alerts for the same synthetic IP |
| `offhours` | Unusual-hours detection |
| `bulk` | Bulk file-access detection |

## Deploy for free

See **[DEPLOYMENT.md](DEPLOYMENT.md)** for the step-by-step Cloudflare Pages + Render + Neon guide, environment variables, security checklist, and limitations.

The free Render backend sleeps after 15 minutes without inbound traffic and can take about a minute to wake. This setup provides a stable public URL, but it is not an always-on uptime guarantee.

## API overview

Authentication uses JWT. Sign in first and include `Authorization: Bearer <token>` for protected routes.

| Method | Route | Purpose |
|---|---|---|
| GET | `/api/health` | Backend health |
| POST | `/api/auth/register` | Create an ANALYST account |
| POST | `/api/auth/login` | Get a JWT |
| POST | `/api/logs/single` | Ingest one event |
| POST | `/api/logs` | Ingest a batch |
| GET | `/api/logs` | Read recent events |
| GET | `/api/alerts` | Read alerts |
| GET | `/api/dashboard` | Dashboard metrics |
| PATCH | `/api/alerts/{id}/status` | Update alert status |
| POST / GET | `/api/alerts/{id}/notes` | Add / list investigation notes |
| GET | `/api/admin/users` | Admin: list users |
| PATCH | `/api/admin/users/{id}/role` | Admin: change a role |
| GET | `/api/admin/rules` | Admin: list detection rules |
| PUT | `/api/admin/rules/{id}` | Admin: enable / disable a rule |
| GET | `/api/admin/audit` | Admin: audit records |
| WebSocket | `/ws` | STOMP endpoint; alerts are published to `/topic/alerts` |

## Security and project limitations

- This is an educational demonstration, not a production SOC. Do not connect it to real company networks or sensitive data without a security review.
- Use unique, strong production credentials and a new JWT secret. Never commit `.env` or production secrets.
- Registration is currently enabled and creates ANALYST accounts. Review whether that is appropriate before sharing the public URL.
- WebSocket authentication and authorization of subscriptions are not yet implemented; do not send sensitive alert data to this public demo.
- Browser JWTs are stored in local storage. This is acceptable for a controlled student demo but is not the preferred production design.
- Free hosting may sleep, restart, or change its limits. The deployment guide explains the operational trade-offs.
