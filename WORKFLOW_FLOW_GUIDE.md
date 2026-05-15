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

## 🛡️ Resilience Tip
If any step fails (e.g., Gmail is down), the status will remain as it was (e.g., `enriched`). The **Outreach Engine** will automatically try to process it again in its next 15-minute run, ensuring no lead is ever forgotten!
