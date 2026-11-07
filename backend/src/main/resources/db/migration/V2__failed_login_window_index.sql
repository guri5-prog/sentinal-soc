CREATE INDEX IF NOT EXISTS idx_logs_failed_login_window
    ON log_events (ip, event_timestamp)
    WHERE source_type = 'LOGIN' AND outcome = 'FAILURE';
