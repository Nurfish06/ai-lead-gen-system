import pool from "../db/db.js";
import { generateEmail } from "../services/aiService.js";
import { sendEmail } from "../services/emailService.js";

export async function getNewLeads(req, res) {
    const result = await pool.query("SELECT * FROM leads WHERE status = 'new'");
    res.json(result.rows);
}
export async function createLead(req, res) {
    const { name, email, company, industry } = req.body;
    const result = await pool.query(
        "INSERT INTO leads (name, email, company, industry) VALUES ($1, $2, $3, $4) RETURNING *",
        [name, email, company, industry]
    );
    res.status(201).json(result.rows[0]);
}
export async function generateAndSendEmail(req, res) {
    const { id } = req.params;

    // Fetch lead
    const leadResult = await pool.query("SELECT * FROM leads WHERE id = $1", [id]);
    const lead = leadResult.rows[0];

    if (!lead) return res.status(404).json({ error: "Lead not found" });

    // Generate email
    const emailText = await generateEmail(lead);

    // Send email
    await sendEmail(lead.email, "Quick question", emailText);

    // Update status
    await pool.query("UPDATE leads SET status = 'contacted' WHERE id = $1", [id]);

    // Log outreach
    await pool.query(
        "INSERT INTO outreach_logs (lead_id, email_sent) VALUES ($1, true)",
        [id]
    );

    res.json({ success: true, email: emailText });
}

export async function getLeadsForFollowup(req, res) {
    const result = await pool.query(`
    SELECT l.*, ol.followup_count 
    FROM leads l
    JOIN outreach_logs ol ON l.id = ol.lead_id
    WHERE ol.replied = false AND ol.followup_count < 3
  `);
    res.json(result.rows);
}