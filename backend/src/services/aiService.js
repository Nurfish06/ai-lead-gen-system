import OpenAI from "openai";
import dotenv from 'dotenv';
dotenv.config();

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

export async function generateEmail(lead) {
    const prompt = `
Write a personalized cold email for:

Name: ${lead.name}
Company: ${lead.company}
Industry: ${lead.industry}

Keep it under 150 words. Be professional but friendly. Include a clear call to action.
  `;

    const response = await openai.chat.completions.create({
        model: "gpt-4o-mini",
        messages: [{ role: "user", content: prompt }],
    });

    return response.choices[0].message.content;
}