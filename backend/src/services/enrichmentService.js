export async function enrichLead(lead) {
    // Placeholder for Clearbit/Apollo API integration
    // For the demo, return mock enriched data
    return {
        ...lead,
        company_size: "50-200",
        linkedin: `https://linkedin.com/in/${lead.name.toLowerCase().replace(' ', '-')}`,
    };
}