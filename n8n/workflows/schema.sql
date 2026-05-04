-- Lead Management Pipeline Database Schema Extensions

-- 1. Dead Letter Queue (DLQ) for Error Handling
CREATE TABLE IF NOT EXISTS pipeline_errors (
    id SERIAL PRIMARY KEY,
    workflow_name TEXT NOT NULL,
    failed_node TEXT NOT NULL,
    error_message TEXT,
    input_payload JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    retry_count INT DEFAULT 0,
    status TEXT DEFAULT 'pending' -- 'pending', 'retried', 'ignored', 'failed'
);

-- 2. Circuit Breaker Service Health Tracking
CREATE TABLE IF NOT EXISTS service_health (
    service_name TEXT PRIMARY KEY,
    status TEXT NOT NULL DEFAULT 'up', -- 'up', 'down'
    failure_count INT DEFAULT 0,
    last_checked TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_failure TIMESTAMP
);

-- Initialize service_health with default services
INSERT INTO service_health (service_name) VALUES ('enrichment_api'), ('ai_email_api'), ('gmail')
ON CONFLICT (service_name) DO NOTHING;

-- 3. Monitoring & Alerting
CREATE TABLE IF NOT EXISTS pipeline_alerts (
    id SERIAL PRIMARY KEY,
    severity TEXT NOT NULL, -- 'critical', 'warning', 'info'
    title TEXT NOT NULL,
    message TEXT,
    workflow_name TEXT,
    acknowledged BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 4. Outreach Logs Enhancement (Transactional Integrity)
-- Assuming the table already exists, we add/ensure the status column
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='outreach_logs' AND column_name='status') THEN
        ALTER TABLE outreach_logs ADD COLUMN status TEXT DEFAULT 'pending';
    END IF;
END $$;

-- 5. Lead Table State Machine Enhancements
-- Ensure all required columns for the state machine exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='leads' AND column_name='status') THEN
        ALTER TABLE leads ADD COLUMN status TEXT DEFAULT 'pending';
    END IF;
END $$;
