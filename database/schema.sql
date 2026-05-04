-- LeadPulse Full Database Schema

-- 1. Core Leads Table
CREATE TABLE IF NOT EXISTS leads (
    id SERIAL PRIMARY KEY,
    name TEXT,
    email TEXT UNIQUE NOT NULL,
    company TEXT,
    industry TEXT,
    title TEXT,
    company_size TEXT,
    location TEXT,
    linkedin_url TEXT,
    twitter_handle TEXT,
    website TEXT,
    revenue_range TEXT,
    employee_count INT,
    technologies TEXT,
    enrichment_score FLOAT,
    status TEXT DEFAULT 'pending', -- 'pending', 'enriching', 'enriched', 'contacted', 'no_response', 'responded'
    pipeline_status TEXT,
    followup_attempts INT DEFAULT 0,
    email_sent_count INT DEFAULT 0,
    last_outreach TIMESTAMP,
    last_followup_attempt TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Outreach Logs (Transactional)
CREATE TABLE IF NOT EXISTS outreach_logs (
    id SERIAL PRIMARY KEY,
    lead_id INT REFERENCES leads(id),
    email_sent BOOLEAN DEFAULT FALSE,
    sent_at TIMESTAMP,
    email_subject TEXT,
    email_body TEXT,
    status TEXT DEFAULT 'pending', -- 'pending', 'sent', 'failed'
    followup_count INT DEFAULT 0,
    replied BOOLEAN DEFAULT FALSE,
    last_followup_at TIMESTAMP,
    last_followup_body TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Dead Letter Queue (DLQ) for Error Handling
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

-- 4. Circuit Breaker Service Health Tracking
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

-- 5. Monitoring & Alerting
CREATE TABLE IF NOT EXISTS pipeline_alerts (
    id SERIAL PRIMARY KEY,
    severity TEXT NOT NULL, -- 'critical', 'warning', 'info'
    title TEXT NOT NULL,
    message TEXT,
    workflow_name TEXT,
    acknowledged BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 6. Indices for Performance
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_outreach_logs_lead_id ON outreach_logs(lead_id);
CREATE INDEX IF NOT EXISTS idx_pipeline_errors_status ON pipeline_errors(status);
