# 🔄 LeadPulse Workflow Automation Guide

This guide details how data flows through the system's automated pipelines. The system operates as a **State Machine**, where leads progress based on their `status` in the database.

---

## 📥 Stage 0: The Ingestion Engine
**Goal**: Capture leads from any source (Google Forms, Postman, Web Scrapers) and save them to the database.

1.  **The Trigger**: A Webhook endpoint (`/ingest-lead`) or a Google Forms submission.
2.  **The Action**: The **`ingestion.json`** workflow validates the incoming data.
3.  **The Result**: A new record is inserted into the `leads` table with:
    *   **Status**: `pending`
    *   **Data**: Name, Email, and Company.

---

## 🛠️ Engine 1: The Enrichment Pipeline
**Goal**: Take new leads and find their background information (company size, industry, etc.).

1.  **The Trigger**: The **"Lead Pipeline Master Orchestration"** runs every **30 minutes**.
2.  **The Claim**: It searches the database for any leads with `status = 'pending'`.
3.  **The Handoff**: It marks these leads as `enriching` and passes them to the **`enrichment.json`** sub-workflow.
4.  **The Enrichment**: The sub-workflow calls the enrichment API and updates the database:
    *   **New Status**: `enriched`
    *   **Data added**: Employee count, LinkedIn URL, Industry, and a Lead Score.

---

## 🚀 Engine 2: The Outreach Pipeline
**Goal**: Take enriched leads and send them hyper-personalized emails via AI.

1.  **The Trigger**: The **"AI Outreach Workflow"** runs every **15 minutes**.
2.  **The Fetch**: It looks for leads that are already **`enriched`** but haven't been contacted yet.
3.  **The AI Generation**: It sends the lead's data to the **AI Engine** to write a custom email based on their specific company and role.
4.  **The Send**: It uses the **Gmail API** to send the message.
5.  **The Final State**: Once the email is sent successfully, it updates the database:
    *   **New Status**: `contacted`
    *   **Timestamp**: Sets the `last_outreach` time.

---

## 📊 Summary of Status Transitions

| Current Status | Workflow | Action | Next Status |
| :--- | :--- | :--- | :--- |
| `none` | Ingestion | Captures external data | `pending` |
| `pending` | Master Pipeline | Claims lead for processing | `enriching` |
| `enriching` | Enrichment | Finds data & scores lead | `enriched` |
| `enriched` | Outreach | AI writes & Gmail sends | `contacted` |
| `contacted` | Follow-up | Checks for replies | `responded` |

---

## 🚨 The Unhappy Path: Error Handling (DLQ)
**Goal**: Ensure no lead is lost when a system fails.

Every workflow node in LeadPulse is connected to a global **Error Handler**.
1.  **Detection**: If a node fails (e.g., API timeout or Database error), the workflow stops.
2.  **The Dead Letter Queue (DLQ)**: The error is intercepted and saved to the `pipeline_errors` table.
    *   **Payload**: The exact data that was being processed is saved so it can be retried.
    *   **Alert**: A critical notification is sent to the **Alert Manager** (Slack/Email).
3.  **Recovery**: Once the issue is fixed, leads in the DLQ can be manually or automatically retried without losing their place in the sequence.

---

## 🛡️ The Shield: Circuit Breakers & Health
**Goal**: Protect your API keys and sender reputation during outages.

The **Service Health Monitor** acts as a "Circuit Breaker" for external services (Gmail, OpenAI, Enrichment APIs).
1.  **Monitoring**: Every 15 minutes, the system "probes" all external services.
2.  **Tripping the Breaker**: If a service fails 3 times in a row, its status is set to `down` in the `service_health` table.
3.  **Protection**: Workflows check this table *before* running. If a service is `down`, the workflow pauses **before** wasting an execution or potentially damaging your sender reputation.
4.  **Auto-Reset**: Once the service is detected as `up` again, the circuit breaker resets and the pipeline resumes.

---

## 📊 Full Pipeline Summary

| Stage | Status | Workflow | Action | Next Status |
| :--- | :--- | :--- | :--- | :--- |
| **Ingestion** | `none` | Ingestion | Captures external data | `pending` |
| **Enrichment** | `pending` | Master Pipeline | Claims lead for processing | `enriching` |
| **Intelligence** | `enriching` | Enrichment | Finds data & scores lead | `enriched` |
| **Outreach** | `enriched` | Outreach | AI writes & Gmail sends | `contacted` |
| **Follow-up** | `contacted` | Follow-up | Checks for replies | `responded` |
| **ERROR** | `any` | Error Handler | Saves to DLQ for retry | `failed` |

---

## 💡 Resilience Tip
The system uses **Atomic State Management**. We use `FOR UPDATE SKIP LOCKED` in our database queries, which means multiple n8n instances can run at the same time without ever processing the same lead twice.
