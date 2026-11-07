# Free cloud deployment (Cloudflare Pages + Render + Neon)

This deployment keeps the React site static and runs only the Spring Boot API as a cloud container. PostgreSQL is managed by Neon. Redis is no longer required: failed-login detection uses a short time-window query against the existing PostgreSQL log table. The Python ML service remains available for local Docker use, but is disabled on the small free backend by default; rule-based detections continue to work.

> Free plans and signup requirements can change. Render's free web service sleeps after 15 minutes without inbound traffic and may take about a minute to wake. This is not an always-on uptime guarantee. Check the provider's current limits before relying on it for a fixed-time evaluation.

## 0. Security before publishing

The source archive supplied for this update included a local `.env` file. It has deliberately **not** been included in this deployment package. Treat the values in that file as exposed and replace them before deployment:

- Generate a new JWT secret (at least 32 random bytes).
- Change the database password if the old value was used anywhere else.
- Set a new, unique administrator password.
- Never commit `.env`, database credentials, JWT secrets, or production passwords to GitHub.

The `.env.example` file contains placeholders only.

## 1. Create the Neon database

1. Create a Neon account and a new PostgreSQL project.
2. Create or use the default database and database role.
3. Copy the connection string from the Neon dashboard.
4. For Spring Boot, the URL must use the JDBC format:

   ```text
   jdbc:postgresql://YOUR_NEON_HOST/YOUR_DATABASE?sslmode=require
   ```

   Use the actual host, database name, username and password shown by Neon. Prefer the direct (non-pooled) connection string for Flyway migrations if Neon offers both pooled and direct strings.
5. Keep the database password private. Neon free compute may scale to zero when idle; the first database connection can take longer while it resumes.

Neon: https://neon.com/

## 2. Push the project to a private GitHub repository

1. Create a **private** GitHub repository.
2. From this project directory, initialise Git if needed, commit the source, and push it.
3. Confirm that `.env` is not staged or committed:

   ```powershell
   git status --short
   git check-ignore .env
   ```

4. Do not upload `target/`, `node_modules/`, `dist/`, Python caches, or local secrets.

The included `.gitignore` excludes these files.

## 3. Deploy the backend on Render

1. Sign in to Render and create a new **Web Service** from your GitHub repository.
2. Select Docker as the runtime.
3. Set **Root Directory** to `backend`.
4. Set **Dockerfile Path** to `./Dockerfile` (relative to the backend root directory).
5. Choose the **Free** instance if it is offered to your account.
6. Set the health check path to `/api/health`.
7. Add these environment variables in Render. Do not put them in source code:

   | Key | Value |
   |---|---|
   | `SPRING_DATASOURCE_URL` | Neon JDBC URL from step 1 |
   | `SPRING_DATASOURCE_USERNAME` | Neon database role |
   | `SPRING_DATASOURCE_PASSWORD` | Neon database password |
   | `JWT_SECRET` | New random secret, at least 32 bytes |
   | `SOC_ADMIN_EMAIL` | Your chosen admin email |
   | `SOC_ADMIN_PASSWORD` | New strong admin password |
   | `APP_CORS_ORIGINS` | `http://localhost:5173` initially; replace after Pages deployment |
   | `ML_ENABLED` | `false` |
   | `DB_POOL_SIZE` | `3` |
   | `SERVER_TOMCAT_THREADS_MAX` | `20` |

8. Deploy and wait for the service to become healthy.
9. Copy the public backend URL, for example `https://your-soc-api.onrender.com`.
10. Test `https://YOUR-RENDER-URL/api/health`. It should return JSON with status `ok`.

Render free web services sleep after 15 minutes of inactivity and can take about a minute to wake. The free instance has 512 MB RAM; this project caps the Java heap to reduce memory pressure, but you must check the Render logs for out-of-memory or restart errors. A successful build alone does not prove the service is stable.

Render free service documentation: https://render.com/docs/free

## 4. Deploy the frontend to Cloudflare Pages (Direct Upload)

Direct Upload lets you build the React app on your own laptop and upload only the static `dist` directory. No frontend server or laptop needs to stay running after deployment.

1. Open `frontend/.env.production.example` and copy it to `frontend/.env.production`.
2. Set `VITE_API_BASE_URL` to your Render backend URL, without a trailing slash. Example:

   ```text
   VITE_API_BASE_URL=https://your-soc-api.onrender.com
   ```

3. In PowerShell, from the `frontend` directory, run:

   ```powershell
   npm install
   npm run build
   ```

4. In Cloudflare Dashboard, go to **Workers & Pages → Create → Pages → Direct Upload**.
5. Give the project a name and upload the `frontend/dist` folder (or a ZIP containing its contents).
6. Cloudflare will provide a URL such as `https://your-soc.pages.dev`.

Cloudflare Pages Direct Upload documentation: https://developers.cloudflare.com/pages/get-started/direct-upload/

## 5. Set the final CORS origin

Go back to the Render backend environment variables and change:

```text
APP_CORS_ORIGINS=https://your-soc.pages.dev,http://localhost:5173
```

Use the exact Pages origin assigned to your project. Save the variable and redeploy/restart the backend. The same origin setting is used for REST CORS and the WebSocket handshake.

## 6. Verify the deployed app

1. Open the Pages URL in a private/incognito browser window.
2. Sign in using the admin email/password configured on Render.
3. Confirm Overview, Alerts, Log Viewer, Users & Rules, and Audit Trail load.
4. Open browser Developer Tools → Network and confirm API requests go to the Render URL and return successfully.
5. Check the WebSocket connection to `wss://YOUR-RENDER-URL/ws`.
6. Generate sample events from your own machine using the simulator. Point it at the deployed API, then confirm events and alerts appear in the dashboard.
7. Update an alert status and add an investigation note. Refresh the page and confirm the changes persist in Neon.
8. Check Render logs after the service has handled requests. Look for database connection errors, failed migrations, or memory-related restarts.

Simulator example (from the project root):

```powershell
pip install -r simulator/requirements.txt
python simulator/simulate.py --url https://YOUR-RENDER-URL/api/logs/single --email YOUR_ADMIN_EMAIL --password YOUR_ADMIN_PASSWORD --mode normal --count 10
```

Check the simulator's `--help` output if your local copy has different argument options.

## 7. Important limitations and fallback

- Render free web services sleep after 15 minutes of inactivity. The public URL remains assigned, but the first request after sleep may take around a minute.
- Render may restart free instances. The backend container filesystem is ephemeral; all persistent application data is in Neon.
- Neon free compute can suspend/scale to zero while idle. Allow for a database wake-up on the first request.
- Render's free instance has only 512 MB RAM. If the service repeatedly restarts or runs out of memory, this architecture is not viable on that free instance. Do not hide or ignore those errors.
- ML anomaly scoring is disabled in the hosted environment. Rule-based brute-force, off-hours and bulk-file-access detections remain enabled. Local Docker Compose still enables the Python ML service.
- The live alert WebSocket is hosted by the Spring Boot process. It reconnects when the frontend is open, but it is not a durable message queue.
- Free plans do not provide an uptime SLA. This is a student demonstration setup, not production hosting.

If Render does not let you create a free Docker web service without adding a payment method, stop there rather than entering someone else's card or selecting a paid plan. Ask your department for a hosted VM or evaluation server instead.
