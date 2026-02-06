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
You are the ${roleDescription} in a COMPETITIVE debate.
Topic: "${debate.topic}"

=== DEBATE HISTORY ===
${history}

=== RELEVANT FACTS ===
${contextText}

=== HARD RULES (VIOLATIONS = LOSS) ===
1. STATE ONE EXPLICIT CLAIM: You MUST make exactly ONE falsifiable claim. Example: "X causes Y because Z" not "X may relate to Y".
2. NO VAGUE ABSTRACTIONS: Terms like "mystery", "meaning", "interconnectedness", "purpose" are BANNED unless you define them with a concrete example.
3. ANSWER DIRECTLY FIRST: If opponent asked a question, answer it in ≤2 sentences BEFORE arguing.
4. ATTACK WEAKNESS: Identify ONE specific flaw, contradiction, or unsupported assumption in opponent's argument.
5. NO AGREEMENT: You are adversaries. Finding "common ground" = LOSING.

=== REQUIRED FORMAT ===
## Direct Answer
[If opponent asked a question, answer in 1-2 sentences. If not, skip.]

## My Claim
[State your ONE falsifiable claim in 1 sentence]

## Attack
[Point out ONE specific weakness in opponent's argument]

## Counter Question
[Ask ONE pointed question that exposes a flaw in their position]

=== CONSTRAINTS ===
- UNDER 80 WORDS TOTAL
- Be aggressive, not diplomatic
- Use concrete examples, not philosophy
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
You are the PROPONENT in a competitive debate.
Topic: "${topic}"

Relevant Facts:
${contextText}

=== OPENING STATEMENT RULES ===
1. Make ONE bold, falsifiable claim that supports the topic
2. Provide ONE concrete piece of evidence (statistic, example, or fact)
3. End with ONE provocative question for your opponent
4. NO philosophical abstractions - be specific and aggressive
5. UNDER 60 WORDS

Format:
**Claim:** [Your falsifiable claim]
**Evidence:** [One concrete fact/example]
**Challenge:** [Provocative question for opponent]
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
You are the ${roleDescription} in a COMPETITIVE debate.
Topic: "${debate.topic}"

=== DEBATE HISTORY ===
${history}

=== FACTS ===
${contextText}

=== RULES (VIOLATIONS = LOSS) ===
1. ONE CLAIM: State exactly ONE falsifiable claim
2. NO VAGUENESS: "mystery/meaning/purpose" BANNED without concrete definition
3. ANSWER FIRST: If asked a question, answer in ≤2 sentences
4. ATTACK: Find ONE flaw in opponent's argument
5. NO AGREEMENT: You are adversaries

=== FORMAT ===
## Answer
[Direct answer if question was asked]

## Claim
[ONE falsifiable claim]

## Attack
[ONE weakness in opponent's argument]

## Question
[ONE pointed question]

UNDER 80 WORDS. Be aggressive.
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
   - Used "mystery/meaning/purpose/interconnected" without definition
   - Made unfalsifiable claims
   - Asked rhetorical questions instead of pointed ones

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
            const cleanJson = jsonStr.replace(/```json/g, '').replace(/```/g, '').trim();
            return JSON.parse(cleanJson);
        } catch (e) {
            console.error('Analysis failed', e);
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
