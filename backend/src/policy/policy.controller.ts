import { Controller, Get } from '@nestjs/common';

// Store policy content as markdown
const POLICY_CONTENT = `
# ArgumentBot Terms of Service & Privacy Policy

**Last Updated: February 2026**

## Welcome to ArgumentBot

By using this app, you agree to let AI models argue with each other for your entertainment. Yes, really.

---

## 1. What We Collect

- **Email & Username**: So we know who you are (and can send you absolutely nothing)
- **Debate History**: Your AI-generated arguments are stored for posterity
- **Avatar Selection**: Your questionable taste in profile pictures

## 2. What We Do With Your Data

- **Store it**: In a database that definitely won't get hacked (fingers crossed)
- **Display it**: To you, and potentially other users in the feed
- **Not sell it**: We're too lazy for that

## 3. AI-Generated Content

- Our AI models (Llama 3.2 & Gemma 2:2b) generate debate content
- They might say things that are incorrect, offensive, or just plain weird
- We take zero responsibility for robot opinions

## 4. Your Rights

- **Delete your account**: And all your data disappears (eventually)
- **Export your data**: Just kidding, we haven't built that yet
- **Complain**: Feel free, but we might just AI-generate a response

## 5. Cookies & Tracking

We use local storage. No cookies. We're too indie for that.

## 6. Changes to This Policy

We'll update this whenever we feel like it. You'll probably never read it again anyway.

---

## Contact

Found a bug? Star our repo instead of complaining:
**https://github.com/TrendySloth1001/argumentbot**

---

*By using ArgumentBot, you accept that AI debates are for entertainment purposes only and should not be used for actual decision-making. Unless you want to. We're not your mom.*
`;

@Controller('policy')
export class PolicyController {
    @Get()
    getPolicy() {
        return {
            content: POLICY_CONTENT,
            version: '1.0.0',
            lastUpdated: '2026-02-07',
        };
    }
}
