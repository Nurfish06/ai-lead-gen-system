import { Router } from "express";
import { getNewLeads, generateAndSendEmail, getLeadsForFollowup } from "../controllers/leadController.js";

const router = Router();

router.get("/new", getNewLeads);
router.post("/new", createLead);
router.post("/send-email/:id", generateAndSendEmail);
router.get("/followup", getLeadsForFollowup);

export default router;