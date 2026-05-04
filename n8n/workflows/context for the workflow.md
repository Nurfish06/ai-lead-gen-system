You are an expert n8n workflow developer and solution architect. I have a lead management pipeline consisting of four n8n workflows. Your task is to redesign and refactor all four workflows to be production-grade, with a primary focus on error handling, resilience, security, and observability.

### Current System Context

The system has four workflows:
1. **Lead Enrichment Workflow** - Triggered by webhook, calls an enrichment API, parses data, saves to PostgreSQL, and responds to the webhook.
2. **Automated Follow-up Workflow** - Runs every 12 hours, fetches leads needing follow-up, sends Gmail follow-ups based on attempt count, updates stats, and marks leads as "no_response" after 3 attempts.
3. **Lead Pipeline Master Orchestration** - Runs every 30 minutes, fetches pending leads, splits into batches, triggers the Enrichment Workflow as a child workflow, and updates database status.
4. **AI Email Outreach Workflow** - Runs every 15 minutes, fetches enriched leads, calls an AI email generation API, sends via Gmail, logs the attempt, and applies a cooldown.

### MANDATORY REQUIREMENTS - Implement All of These

#### 1. Error Handling & Dead Letter Queue (DLQ)
- Create a new "Error Handler" workflow that receives failed payloads via webhook and inserts them into a new PostgreSQL table called `pipeline_errors` with columns: `id (serial)`, `workflow_name (text)`, `failed_node (text)`, `error_message (text)`, `input_payload (jsonb)`, `created_at (timestamp)`, `retry_count (int DEFAULT 0)`, `status (text DEFAULT 'pending')`.
- On EVERY HTTP request node (Call Enrichment API, Generate AI Email), EVERY database node (Save to Database, Update Follow-up Stats, Log Outreach Attempt, Mark as No Response, Update Database), and EVERY Gmail node, add an error output branch that calls this Error Handler workflow with the complete input payload and error details.
- For HTTP nodes, distinguish between 4xx errors (permanent - no retry) and 5xx/timeout errors (transient - eligible for retry) by setting the appropriate status in the DLQ.

#### 2. SQL Injection Remediation (CRITICAL SECURITY)
- Rewrite ALL PostgreSQL queries to use parameterized queries (Query Parameters mode in n8n).
- Convert all `{{$json.variable}}` interpolations in SQL VALUES/WHERE clauses to named parameters like `:leadId`.
- Example: Change `WHERE id = {{$json.lead_id}}` to `WHERE id = :leadId` with the parameter `leadId` mapped to `{{$json.lead_id}}`.
- Ensure array values (like `technologies`) are properly handled using PostgreSQL array syntax with parameters.

#### 3. Transactional Integrity for Email Operations
- In BOTH the AI Email Outreach Workflow and Automated Follow-up Workflow, implement a "Log-First, Execute-Later" pattern:
  - BEFORE calling Gmail, INSERT a record into `outreach_logs` with `status = 'pending'` and the email content.
  - AFTER Gmail success, UPDATE that same record to `status = 'sent'`.
  - On Gmail failure, UPDATE the record to `status = 'failed'` and route to the DLQ.
- Create a new "Outreach Reconciliation" workflow that runs every 1 hour, finds `outreach_logs` records with `status = 'pending'` older than 15 minutes, and either retries them or alerts an admin.

#### 4. Webhook Security & Idempotency
- Add authentication to the Enrichment Workflow webhook using n8n's Header Auth or Basic Auth credential.
- In the Enrichment Workflow's "Extract Lead Data" node, add a database lookup to check if the lead already exists. If `status` is already `'enriched'` or `'enriching'`, immediately return a 200 OK (idempotent response) and stop processing.
- Return a 409 Conflict if the same lead is currently being processed by another execution.

#### 5. Lead State Machine Implementation
- Define and enforce these explicit lead states: `pending` -> `enriching` -> `enrichment_failed` | `enriched` -> `outreach_queued` -> `contacted` -> `no_response` | `responded`.
- Modify the Master Orchestration workflow to:
  - Fetch only leads with `status = 'pending'`.
  - Immediately UPDATE their status to `enriching` before triggering the child enrichment workflow.
- Modify the Enrichment Workflow: On success, set status to `enriched`. On failure, set status to `enrichment_failed` AND write to the DLQ.
- Modify the AI Outreach Workflow: Fetch only leads with `status = 'enriched'`. On success, set to `contacted`. On failure, set to `enrichment_failed` (to flag for review).

#### 6. Circuit Breaker Pattern
- Add a new "Service Health Monitor" workflow that:
  - Maintains a `service_health` table with columns: `service_name`, `status (up/down)`, `failure_count`, `last_checked`, `last_failure`.
  - Is called by the error branches of all HTTP nodes to increment the failure count for that specific service.
  - Has a condition: If `failure_count >= 5` within the last 10 minutes, flip `status` to `down`.
  - Has a separate recovery path: Every 5 minutes, attempt a health check call. If successful, reset `status` to `up` and `failure_count` to 0.
- In all workflows, BEFORE calling any external API, add a Switch/IF node that checks this `service_health` table. If the service is `down`, skip the call and route directly to a "Service Unavailable" logger that writes to the DLQ with status `circuit_open`.

#### 7. Dynamic Rate Limiting
- Replace ALL static `Wait` nodes with proper `RateLimit` nodes from n8n core nodes, configured per service:
  - Enrichment API: Max 10 calls per minute.
  - AI Email API: Max 5 calls per minute.
  - Gmail: Max 10 calls per minute (per Google Workspace limits).
- In the Master Orchestration, replace the `SplitInBatches` + passive wait approach. Use the `RateLimit` node after `ExecuteWorkflow` to control child workflow spawning rate.

#### 8. Monitoring & Alerting System
- Create an "Alert Manager" workflow that:
  - Accepts alerts via webhook with payload: `severity (critical/warning/info)`, `title`, `message`, `workflow_name`.
  - For `critical` severity: Sends email AND Slack/Teams webhook notification (leave webhook URL as a configurable credential).
  - For `warning` severity: Sends Slack/Teams notification only.
  - For `info` severity: Logs to a `pipeline_alerts` table only.
- Connect the DLQ processing: When `pipeline_errors` gets a new record with `status = 'pending'`, trigger an alert.
- Add alert triggers for: DLQ growth rate exceeding 20 items/hour, any service `down` status change, and leads stuck in `enriching` state for more than 1 hour.

#### 9. Database Schema Additions
Provide the complete SQL DDL for the following new tables:
- `pipeline_errors` (as described above)
- `service_health` (as described above)
- `pipeline_alerts` with columns: `id`, `severity`, `title`, `message`, `workflow_name`, `acknowledged (bool)`, `created_at`
- Modify `outreach_logs` to add a `status` column with values: `pending`, `sent`, `failed`

#### 10. Code Style & Documentation Requirements
- Add clear comments to every Code node explaining the purpose, inputs, and outputs.
- Add a `notes` field to each workflow node explaining its role in the error handling strategy.
- On all SQL nodes, add a `note` field with the query's purpose and a warning if it's part of a transactional boundary.

### DELIVERABLES
For each of the four workflows, provide:
1. The COMPLETE refactored n8n JSON export with all new nodes, connections, and error branches.
2. The NEW Error Handler and Alert Manager workflow JSONs.
3. The NEW Service Health Monitor workflow JSON.
4. The COMPLETE SQL DDL for all new and modified tables.
5. A brief summary document explaining the key architectural changes and how they improve the system.