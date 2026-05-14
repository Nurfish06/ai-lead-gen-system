-- LeadPulse Full Database Schema
CREATE EXTENSION IF NOT EXISTS pgcrypto;

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
    lead_score INT DEFAULT 0,
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
    replied_at TIMESTAMP,
    thread_id TEXT,
    prompt_version TEXT,
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
INSERT INTO service_health (service_name) VALUES ('enrichment_api'), ('ai_email_api'), ('gmail'), ('ollama')
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

-- 7. Security Roles & Least Privilege (RBAC)
-- Note: Run these as a superuser
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'leadpulse_ingestion') THEN
        CREATE ROLE leadpulse_ingestion;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'leadpulse_enrichment') THEN
        CREATE ROLE leadpulse_enrichment;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'leadpulse_outreach') THEN
        CREATE ROLE leadpulse_outreach;
    END IF;
END $$;

-- Ingestion: Can only insert new leads
GRANT INSERT ON leads TO leadpulse_ingestion;
GRANT USAGE, SELECT ON SEQUENCE leads_id_seq TO leadpulse_ingestion;

-- Enrichment: Can read leads and update profile data/status
GRANT SELECT ON leads TO leadpulse_enrichment;
GRANT UPDATE (company_size, industry, linkedin_url, twitter_handle, website, revenue_range, employee_count, technologies, enrichment_score, lead_score, status, updated_at) ON leads TO leadpulse_enrichment;

-- Outreach: Can read leads, insert logs, and update outreach status
GRANT SELECT ON leads TO leadpulse_outreach;
GRANT UPDATE (status, last_outreach, email_sent_count, updated_at) ON leads TO leadpulse_outreach;
GRANT INSERT, SELECT, UPDATE ON outreach_logs TO leadpulse_outreach;
GRANT USAGE, SELECT ON SEQUENCE outreach_logs_id_seq TO leadpulse_outreach;

-- Monitoring: Can read health and errors
GRANT SELECT ON service_health TO leadpulse_outreach, leadpulse_enrichment;
GRANT SELECT, INSERT ON pipeline_errors TO leadpulse_outreach, leadpulse_enrichment, leadpulse_ingestion;
GRANT USAGE, SELECT ON SEQUENCE pipeline_errors_id_seq TO leadpulse_outreach, leadpulse_enrichment, leadpulse_ingestion;

-- 8. Audit Logging (Security & Compliance)
CREATE TABLE IF NOT EXISTS audit_log (
    id SERIAL PRIMARY KEY,
    workflow_name TEXT NOT NULL,
    actor TEXT, -- Service account or system role
    action TEXT NOT NULL, -- e.g., 'READ_PII', 'SEND_EMAIL', 'UPDATE_SCORE'
    lead_id INT,
    details JSONB,
    severity TEXT DEFAULT 'info',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 9. Internal Secrets Vault (Token Broker Pattern)
CREATE TABLE IF NOT EXISTS internal_secrets (
    secret_key TEXT PRIMARY KEY,
    secret_value TEXT NOT NULL,
    description TEXT,
    last_rotated TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Restricted access: Only a dedicated vault role or superuser can read this
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'vault_admin') THEN
        CREATE ROLE vault_admin;
    END IF;
END $$;

REVOKE ALL ON internal_secrets FROM PUBLIC;
GRANT SELECT ON internal_secrets TO vault_admin;

-- Audit Logging for Vault Access
GRANT INSERT ON audit_log TO vault_admin;
