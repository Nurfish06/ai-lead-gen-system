import nodemailer from "nodemailer";
import dotenv from 'dotenv';
dotenv.config();

const transporter = nodemailer.createTransport({
    service: "gmail",
    auth: {
        user: process.env.EMAIL,
        pass: process.env.PASSWORD, // App password, not your real password
    },
});

export async function sendEmail(to, subject, text) {
    await transporter.sendMail({
        from: process.env.EMAIL,
        to,
        subject,
        text,
    });
    console.log(`Email sent to ${to}`);
}