import { Router } from "express";
import { getNewLeads, createLead, generateAndSendEmail, getLeadsForFollowup } from "../controllers/leadController.js";

const router = Router();

router.get("/new", getNewLeads);
router.post("/new", createLead);
router.post("/enrich", (req, res) => {
    const { email, company } = req.body;
    // Return mock enrichment data
    res.json({
        company_size: "500-1000",
        industry: "Technology",
        linkedin_url: `https://linkedin.com/company/${company?.toLowerCase().replace(/\s/g, '')}`,
        revenue_range: "$10M - $50M",
        employee_count: 750,
        technologies: ["aws", "react", "nodejs"],
        confidence_score: 0.95
    });
});
router.post("/send-email/:id", generateAndSendEmail);
router.get("/followup", getLeadsForFollowup);

export default router;