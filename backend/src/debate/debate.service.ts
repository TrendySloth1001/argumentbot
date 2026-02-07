import { Injectable, NotFoundException, Inject } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LlmService } from '../llm/llm.service';
import { RagService } from '../rag/rag.service';
import { ScoringService } from './scoring.service';
import { DebateStatus, Speaker } from '@prisma/client';
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
            include: {
                turns: { take: 1, orderBy: { timestamp: 'desc' } }
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
            include: {
                turns: { take: 1, orderBy: { timestamp: 'desc' } }
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
        const nextSpeaker = lastTurn.speaker === Speaker.MODEL_A ? Speaker.MODEL_B : Speaker.MODEL_A;
        const roleDescription = nextSpeaker === Speaker.MODEL_A ? 'PROPONENT (defending the claim)' : 'OPPONENT (attacking the claim)';
        const activeModel = nextSpeaker === Speaker.MODEL_A ? 'llama3.2' : 'gemma2:2b';

        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map((d) => d.content).join('\n');

        // Build debate history for context
        const history = debate.turns.map(t =>
            `${t.speaker === Speaker.MODEL_A ? 'PRO' : 'CON'}: ${t.content}`
        ).join('\n\n');

        const prompt = `
You are the ${roleDescription} in a COMPETITIVE debate. You have a sharp wit and aren't afraid to roast your opponent.
Topic: "${debate.topic}"

=== DEBATE HISTORY ===
${history}

=== RELEVANT FACTS ===
${contextText}

=== YOUR PERSONALITY ===
- You are confident, witty, and slightly sarcastic
- You enjoy pointing out the absurdity in your opponent's logic
- You use clever analogies and occasionally roast your opponent
- You never insult personally - only their arguments (keep it classy)
- Think of yourself as a debate champion with comedian timing

=== HARD RULES (VIOLATIONS = LOSS) ===
1. STATE ONE EXPLICIT CLAIM: Make exactly ONE falsifiable claim with evidence
2. NO VAGUE ABSTRACTIONS: "mystery/meaning/purpose" BANNED unless defined concretely
3. ANSWER DIRECTLY: If asked a question, answer in ≤2 sentences FIRST
4. ATTACK + ROAST: Point out a flaw AND add a witty comment about it
5. NO AGREEMENT: You are rivals. Finding common ground = LOSING
6. USE CONTEXT: You MUST reference the PROVIDED FACTS. Don't ignore them.

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

        const stream = await this.llmService.generateStream(prompt, activeModel);

        return {
            stream,
            debateId: debate.id,
            speaker: nextSpeaker,
            topic: debate.topic,
            lastTurnContent: lastTurn.content,
            scoringMode,
            modelName: activeModel
        };
    }

    async saveTurn(debateId: string, speaker: Speaker, content: string, scoringMode: 'AI' | 'ALGO', topic: string, lastTurnContent: string, modelName: string) {
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId,
                speaker,
                content,
                modelName: modelName
            },
        });

        let analysis;
        if (scoringMode === 'ALGO') {
            analysis = this.scoringService.calculateScore(content, topic);
        } else {
            analysis = await this.analyzeTurn(topic, lastTurnContent, content);
        }

        await this.prisma.debateTurn.update({
            where: { id: newTurn.id },
            data: { analysis },
        });

        await this.cacheManager.del(`debate:${debateId}`);
        await this.cacheManager.del('debates:all');

        return newTurn;
    }

    async startDebate(topic: string, userId?: string) {
        const debate = await this.prisma.debate.create({
            data: {
                topic,
                status: DebateStatus.ACTIVE,
                userId: userId || null,
            },
        });

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
                speaker: Speaker.MODEL_A,
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
        const nextSpeaker = lastTurn.speaker === Speaker.MODEL_A ? Speaker.MODEL_B : Speaker.MODEL_A;
        const roleDescription = nextSpeaker === Speaker.MODEL_A ? 'PROPONENT (defending)' : 'OPPONENT (attacking)';
        const activeModel = nextSpeaker === Speaker.MODEL_A ? 'llama3.2' : 'gemma2:2b';

        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map((d) => d.content).join('\n');

        const history = debate.turns.map(t =>
            `${t.speaker === Speaker.MODEL_A ? 'PRO' : 'CON'}: ${t.content}`
        ).join('\n\n');

        const prompt = `
You are the ${roleDescription} in a COMPETITIVE debate. You have sharp wit and love to roast your opponent's arguments.
Topic: "${debate.topic}"

=== DEBATE HISTORY ===
${history}

=== FACTS ===
${contextText}

=== YOUR PERSONALITY ===
- Confident, witty, slightly sarcastic
- You enjoy exposing the absurdity in opponent's logic
- Use clever analogies and occasional roasts
- Attack arguments, not the person (keep it classy)

=== RULES (VIOLATIONS = LOSS) ===
1. ONE CLAIM: State exactly ONE falsifiable claim with evidence
2. NO VAGUENESS: "mystery/meaning/purpose" BANNED without concrete definition
3. ANSWER FIRST: If asked a question, answer in ≤2 sentences
4. ATTACK + ROAST: Find a flaw AND add a witty comment
5. NO AGREEMENT: You are rivals
6. USE CONTEXT: Reference facts from the PROVIDED CONTEXT.

=== BANNED PHRASES (INSTANT LOSS) ===
- "Mystery / complex / nuance" (without definition)
- "Balance / Middle ground" (Weak)
- "Subjective meaning" (Vague)
- "Interconnected" (Lazy)

=== FORMAT ===
## Answer
[Direct answer if question was asked]

## Claim
[ONE falsifiable claim with attitude]

## Attack
[ONE weakness + clever roast or analogy]

## Question
[ONE pointed question to put them on the spot]

UNDER 100 WORDS. Be sharp, witty, confident. Roast their logic!
NO META-COMMENTARY. NO "Explanation:". JUST THE RESPONSE.
`;

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

=== OUTPUT ===
Return ONLY valid JSON:
{
    "persuasiveness": <number 0-100, average of above minus penalties>,
    "claim_score": <number 0-100>,
    "answer_score": <number 0-100>,
    "attack_score": <number 0-100>,
    "vagueness_penalty": <number, negative>,
    "key_point": "<one sentence summary of their main claim>",
    "weakness": "<one sentence describing the biggest flaw>"
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
                weakness: "Could not analyze"
            };
        }
    }
}
