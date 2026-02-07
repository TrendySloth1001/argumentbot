import { Injectable, NotFoundException, Inject } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LlmService } from '../llm/llm.service';
import { RagService } from '../rag/rag.service';
import { ScoringService } from './scoring.service';
import { DebateStatus, Speaker, DebateMode, DebateRole } from '@prisma/client';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';

@Injectable()
export class DebateService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly llmService: LlmService,
        private readonly ragService: RagService,
        private readonly scoringService: ScoringService,
        @Inject(CACHE_MANAGER) private cacheManager: Cache,
    ) { }

    async getDebate(id: string) {
        const cacheKey = `debate:${id}`;
        const cached = await this.cacheManager.get(cacheKey);
        if (cached) return cached;

        const debate = await this.prisma.debate.findUnique({
            where: { id },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });

        if (debate) await this.cacheManager.set(cacheKey, debate, 600000);
        return debate;
    }

    async getAllDebates() {
        const cacheKey = 'debates:all';
        const cached = await this.cacheManager.get(cacheKey);
        if (cached) return cached;

        const debates = await this.prisma.debate.findMany({
            orderBy: { createdAt: 'desc' },
            select: {
                id: true,
                topic: true,
                status: true,
                mode: true,
                userRole: true,
                createdAt: true,
                updatedAt: true,
                userId: true,
                turns: {
                    take: 1,
                    orderBy: { timestamp: 'desc' },
                    select: {
                        speaker: true,
                        content: true,
                        timestamp: true,
                        modelName: true
                    }
                }
            }
        });

        await this.cacheManager.set(cacheKey, debates, 600000);
        return debates;
    }

    async getDebatesByUser(userId: string) {
        const cacheKey = `debates:user:${userId}`;
        const cached = await this.cacheManager.get(cacheKey);
        if (cached) return cached;

        const debates = await this.prisma.debate.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
            select: {
                id: true,
                topic: true,
                status: true,
                mode: true,
                userRole: true,
                createdAt: true,
                updatedAt: true,
                userId: true,
                turns: {
                    take: 1,
                    orderBy: { timestamp: 'desc' },
                    select: {
                        speaker: true,
                        content: true,
                        timestamp: true,
                        modelName: true
                    }
                }
            }
        });

        await this.cacheManager.set(cacheKey, debates, 600000);
        return debates;
    }

    async processTurnStream(debateId: string, scoringMode: 'AI' | 'ALGO' = 'AI') {
        const debate = await this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });

        if (!debate) throw new NotFoundException('Debate not found');
        if (debate.status === DebateStatus.FINISHED) {
            return { finished: true };
        }

        const lastTurn = debate.turns[debate.turns.length - 1];
        let nextSpeaker: Speaker;

        if (debate.mode === DebateMode.USER_VS_AI) {
            // In User vs AI, last turn implies next speaker
            if (lastTurn.speaker === Speaker.USER) {
                // AI's turn
                nextSpeaker = debate.userRole === DebateRole.PRO ? Speaker.MODEL_B : Speaker.MODEL_A;
            } else {
                // Waiting for user input
                return { finished: true, waitingForUser: true };
            }
        } else {
            nextSpeaker = lastTurn.speaker === Speaker.MODEL_A ? Speaker.MODEL_B : Speaker.MODEL_A;
        }

        const roleDescription = nextSpeaker === Speaker.MODEL_A ? 'PROPONENT (defending the claim)' : 'OPPONENT (attacking the claim)';
        const activeModel = nextSpeaker === Speaker.MODEL_A ? 'llama3.2' : 'gemma2:2b';

        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map((d) => d.content).join('\n');

        const history = debate.turns.map(t =>
            `${t.speaker === Speaker.MODEL_A ? 'PRO' : (t.speaker === Speaker.MODEL_B ? 'CON' : 'USER')}: ${t.content}`
        ).join('\n\n');

        let opponentDescription = 'ANOTHER AI MODEL';
        if (debate.mode === DebateMode.USER_VS_AI) {
            opponentDescription = 'THE USER (A REAL HUMAN)';
        }

        const lastTurnConceded = lastTurn.analysis && (lastTurn.analysis as any).conceded === true;

        let prompt = '';
        if (lastTurnConceded) {
            prompt = `
You are the ${roleDescription} in a COMPETITIVE debate.
Your opponent (${opponentDescription}) has CONCEDED!

Victory is yours.
Give a short, witty, and slightly gloating victory speech.
Be gracious but remind them why you won.
UNDER 50 WORDS.
NO META-COMMENTARY.
`;
        } else {
            prompt = `
You are the ${roleDescription} in a COMPETITIVE debate.
Your opponent (${opponentDescription}) has CONCEDED! (Wait, no, this is the else block).
You are debating against ${opponentDescription}. Your goal is to defeat them logically and rhetorically.

Topic: "${debate.topic}"

=== DEBATE HISTORY ===
${history}

=== RELEVANT FACTS ===
${contextText}

=== YOUR PERSONALITY ===
- You are confident, witty, and slightly sarcastic
- You enjoy pointing out the absurdity in your opponent's logic
- You use clever analogies and occasionally roast your opponent (argument based)

=== HARD RULES (VIOLATIONS = LOSS) ===
1. STATE ONE EXPLICIT CLAIM: Make exactly ONE falsifiable claim with evidence
2. NO VAGUE ABSTRACTIONS: "mystery/meaning/purpose" BANNED unless defined concretely
3. ANSWER DIRECTLY: If asked a question, answer in ≤2 sentences FIRST
4. ATTACK + ROAST: Point out a flaw AND add a witty comment about it
5. NO AGREEMENT (UNLESS DEFEATED): You are rivals. Finding common ground = LOSING.
6. CONCESSION ALLOWED: If your opponent's logic is undeniable and you are cornered, you MAY concede. (e.g., "You got me there.", "I yield.").
7. USE CONTEXT: You MUST reference the PROVIDED FACTS. Don't ignore them.

=== BANNED PHRASES (INSTANT LOSS) ===
- "It's a mystery / complex issue" (Cop-out)
- "We must find a balance" (Weak)
- "Meaning is subjective" (Vague)
- "Interconnected / Nuanced" (Unless defined concretely)
- "Let's agree to disagree" (BANNED)

=== REQUIRED FORMAT ===
## Direct Answer
[Answer opponent's question in 1-2 sentences. Skip if none.]

## My Claim
[ONE falsifiable claim with attitude]

## Attack
[ONE weakness + a clever roast or analogy]

## Counter Question
[ONE pointed question that puts them on the spot]

=== STYLE ===
- UNDER 100 WORDS TOTAL
- Be sharp, witty, confident
- Use humor and clever comparisons
- Roast their logic, not them personally
- NO META-COMMENTARY: Do NOT include "Explanation:", "Analysis:", or notes. JUST the debate response.
`;
        }

        const stream = await this.llmService.generateStream(prompt, activeModel);

        return {
            stream,
            debateId: debate.id,
            speaker: nextSpeaker,
            topic: debate.topic,
            lastTurnContent: lastTurn.content,
            scoringMode,
            modelName: activeModel,
            lastTurnConceded // Pass this to controller so it can pass to saveTurn
        };
    }

    async saveTurn(debateId: string, speaker: Speaker, content: string, scoringMode: 'AI' | 'ALGO', topic: string, lastTurnContent: string, modelName: string, lastTurnConceded: boolean = false) {
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId,
                speaker,
                content,
                modelName: modelName
            },
        });

        let analysis;
        // If it's a victory speech (lastTurnConceded), maybe skip full analysis or give max score?
        // But let's analyze anyway to see if AI messed up the victory speech.

        if (scoringMode === 'ALGO') {
            analysis = this.scoringService.calculateScore(content, topic);
        } else {
            analysis = await this.analyzeTurn(topic, lastTurnContent, content);
        }

        await this.prisma.debateTurn.update({
            where: { id: newTurn.id },
            data: { analysis },
        });

        // Check for Game Over conditions
        const aiConceded = (analysis as any).conceded === true;

        if (aiConceded || lastTurnConceded) {
            await this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED }
            });
        }

        await this.cacheManager.del(`debate:${debateId}`);
        await this.cacheManager.del('debates:all');

        return newTurn;
    }

    async submitUserTurn(debateId: string, content: string) {
        const debate = await this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: { orderBy: { timestamp: 'desc' }, take: 1 } }
        });

        if (!debate) throw new NotFoundException('Debate not found');
        if (debate.status === DebateStatus.FINISHED) throw new Error('Debate finished');

        // Save user turn
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId,
                speaker: Speaker.USER,
                content,
                modelName: 'User'
            }
        });

        // Analyze user turn? Yes, let the judge score the user!
        const lastTurnContent = debate.turns[0]?.content || '';
        const analysis = await this.analyzeTurn(debate.topic, lastTurnContent, content);

        await this.prisma.debateTurn.update({
            where: { id: newTurn.id },
            data: { analysis }
        });

        await this.cacheManager.del(`debate:${debateId}`);

        return newTurn;
    }

    async startDebate(topic: string, userId?: string, mode: DebateMode = DebateMode.AI_VS_AI, userRole: DebateRole = DebateRole.SPECTATOR) {
        const debate = await this.prisma.debate.create({
            data: {
                topic,
                status: DebateStatus.ACTIVE,
                userId: userId || null,
                mode,
                userRole
            },
        });

        // If User vs AI and User is PRO, User speaks first.
        // Return immediately, waiting for user input.
        if (mode === DebateMode.USER_VS_AI && userRole === DebateRole.PRO) {
            return debate;
        }

        // If AI vs AI OR (User vs AI and User is CON), AI starts (Proponent).
        // Standard flow below.

        const context = await this.ragService.searchSimilar(topic);
        const contextText = context.map(c => c.content).join('\n');

        const prompt = `
You are the PROPONENT in a competitive debate. You're confident, witty, and ready to dominate.
Topic: "${topic}"

Relevant Facts:
${contextText}

=== YOUR PERSONALITY ===
- Confident and slightly cocky
- Use clever analogies and sharp wit
- Make your opponent sweat with your opening

=== OPENING STATEMENT RULES ===
1. Make ONE bold, falsifiable claim that supports the topic
2. Provide ONE concrete piece of evidence (statistic, example, or fact)  
3. End with a PROVOCATIVE challenge that puts pressure on opponent
4. Add a dash of wit or a clever analogy
5. UNDER 80 WORDS

Format:
**Claim:** [Your bold, falsifiable claim]
**Evidence:** [One concrete fact/example]
**Challenge:** [Provocative question with some swagger]

NO EXPLANATION OR META-COMMENTARY. JUST THE RESPONSE.
`;

        const response = await this.llmService.generateResponse(prompt);

        await this.prisma.debateTurn.create({
            data: {
                debateId: debate.id,
                speaker: Speaker.MODEL_A, // AI is always Model A (Pro) or Model B (Con). Or keep it simple.
                // In User vs AI (User=Con), AI is Pro (Model A). Correct.
                content: response,
                modelName: 'llama3.2'
            },
        });

        await this.cacheManager.del('debates:all');
        if (userId) {
            await this.cacheManager.del(`debates:user:${userId}`);
        }
        return debate;
    }

    async processTurn(debateId: string, scoringMode: 'AI' | 'ALGO' = 'AI') {
        const debate = await this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });

        if (!debate) throw new NotFoundException('Debate not found');
        if (debate.status === DebateStatus.FINISHED) return debate;

        if (debate.turns.length >= 6) {
            return this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED },
                include: { turns: true },
            });
        }

        const lastTurn = debate.turns[debate.turns.length - 1];
        let nextSpeaker: Speaker;

        if (debate.mode === DebateMode.USER_VS_AI) {
            if (lastTurn.speaker === Speaker.USER) {
                nextSpeaker = debate.userRole === DebateRole.PRO ? Speaker.MODEL_B : Speaker.MODEL_A;
            } else {
                // Wait for user or error?
                // If last speaker was AI, we shouldn't be processing AI turn again unless retrying.
                // For now assume caller checked.
                // Or force AI vs AI logic if something weird happens.
                nextSpeaker = debate.userRole === DebateRole.PRO ? Speaker.MODEL_B : Speaker.MODEL_A;
            }
        } else {
            nextSpeaker = lastTurn.speaker === Speaker.MODEL_A ? Speaker.MODEL_B : Speaker.MODEL_A;
        }

        const roleDescription = nextSpeaker === Speaker.MODEL_A ? 'PROPONENT (defending)' : 'OPPONENT (attacking)';
        const activeModel = nextSpeaker === Speaker.MODEL_A ? 'llama3.2' : 'gemma2:2b';

        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map((d) => d.content).join('\n');

        const history = debate.turns.map(t =>
            `${t.speaker === Speaker.MODEL_A ? 'PRO' : 'CON'}: ${t.content}`
        ).join('\n\n');

        let opponentDescription = 'ANOTHER AI MODEL';
        if (debate.mode === DebateMode.USER_VS_AI) {
            opponentDescription = 'THE USER (A REAL HUMAN)';
        }

        const lastTurnConceded = lastTurn.analysis && (lastTurn.analysis as any).conceded === true;

        let prompt = '';
        if (lastTurnConceded) {
            prompt = `
You are the ${roleDescription} in a COMPETITIVE debate.
Your opponent (${opponentDescription}) has CONCEDED!

Victory is yours.
Give a short, witty, and slightly gloating victory speech.
Be gracious but remind them why you won.
UNDER 50 WORDS.
NO META-COMMENTARY.
`;
        } else {
            prompt = `
You are the ${roleDescription} in a COMPETITIVE debate.
You are debating against ${opponentDescription}. Your goal is to defeat them logically and rhetorically.

Topic: "${debate.topic}"

=== DEBATE HISTORY ===
${history}

=== FACTS ===
${contextText}

=== YOUR PERSONALITY ===
[ONE pointed question to put them on the spot]

UNDER 100 WORDS. Be sharp, witty, confident. Roast their logic!
NO META-COMMENTARY. NO "Explanation:". JUST THE RESPONSE.
`;
        }

        const responseContent = await this.llmService.generateResponse(prompt, activeModel);

        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId: debate.id,
                speaker: nextSpeaker,
                content: responseContent,
                modelName: activeModel
            },
        });

        let analysis;
        if (scoringMode === 'ALGO') {
            analysis = this.scoringService.calculateScore(responseContent, debate.topic);
        } else {
            analysis = await this.analyzeTurn(debate.topic, lastTurn.content, responseContent);
        }

        await this.prisma.debateTurn.update({
            where: { id: newTurn.id },
            data: { analysis },
        });

        // Check for Game Over conditions
        const aiConceded = (analysis as any).conceded === true;

        if (aiConceded || lastTurnConceded) {
            await this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED }
            });
            return this.prisma.debate.findUnique({
                where: { id: debateId },
                include: { turns: { orderBy: { timestamp: 'asc' } } },
            });
        }

        await this.cacheManager.del(`debate:${debateId}`);
        await this.cacheManager.del('debates:all');

        return this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });
    }

    private async analyzeTurn(topic: string, opponentArg: string, response: string): Promise<any> {
        const prompt = `
You are a STRICT debate judge. Analyze this exchange:

Topic: "${topic}"
Opponent said: "${opponentArg}"
Response: "${response}"

=== SCORING CRITERIA ===

1. CLAIM QUALITY (0-100):
   - 100: Clear falsifiable claim with evidence
   - 50: Vague claim, no evidence
   - 0: No claim or pure abstraction

2. DIRECT ANSWER (0-100):
   - 100: Answered opponent's question directly
   - 50: Partially addressed
   - 0: Ignored or deflected (MAJOR PENALTY)

3. ATTACK STRENGTH (0-100):
   - 100: Identified specific flaw with counter-evidence
   - 50: Generic disagreement
   - 0: Agreed or didn't challenge

4. VAGUENESS PENALTY (-30 for each):
   - Used "mystery/meaning/purpose/interconnected" without concrete definition
   - Made unfalsifiable claims (e.g. "it's too complex to know")
   - Asked rhetorical questions instead of pointed ones
   - Failed to use provided context/facts (if applicable)

5. NON-ANSWER PENALTY (-50):
   - Did not directly address the opponent's question with a Yes/No/Because statement.

=== VICTORY CHECK (INSTANT END) ===
- Did the speaker EXPLICITLY concede? e.g. "I quit", "You're right", "I give up".
- Did they refuse to continue arguing?
- -> Set "conceded": true

=== OUTPUT ===
Return ONLY valid JSON:
{
    "persuasiveness": <number 0-100, average of above minus penalties>,
    "claim_score": <number 0-100>,
    "answer_score": <number 0-100>,
    "attack_score": <number 0-100>,
    "vagueness_penalty": <number, negative>,
    "key_point": "<one sentence summary of their main claim>",
    "weakness": "<one sentence describing the biggest flaw>",
    "conceded": <boolean, true if they gave up>
}
`;

        try {
            const jsonStr = await this.llmService.generateResponse(prompt, 'llama3.2');

            // Extract JSON object using regex to handle potential markdown or extra text
            const jsonMatch = jsonStr.match(/\{[\s\S]*\}/);
            if (!jsonMatch) {
                console.error('No JSON found in analysis response:', jsonStr);
                throw new Error('No JSON found');
            }

            return JSON.parse(jsonMatch[0]);
        } catch (e) {
            console.error('Analysis parsing failed:', e);
            return {
                persuasiveness: 50,
                claim_score: 50,
                answer_score: 50,
                attack_score: 50,
                vagueness_penalty: 0,
                key_point: "Analysis unavailable",
                weakness: "Could not analyze",
                conceded: false
            };
        }
    }
}
