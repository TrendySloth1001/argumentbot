import { Injectable, NotFoundException, Inject } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LlmService } from '../llm/llm.service';
import { RagService } from '../rag/rag.service';
import { ScoringService } from './scoring.service';
import { DebateStatus, Speaker, DebateMode, DebateRole, DifficultyLevel } from '@prisma/client';
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

    /**
     * Calculate the current scores for both sides of a debate
     */
    private calculateDebateScores(turns: any[]): { proScore: number; conScore: number } {
        let proScore = 50; // Starting base
        let conScore = 50;

        for (const turn of turns) {
            if (turn.analysis) {
                const persuasiveness = turn.analysis.persuasiveness ?? 50;
                if (turn.speaker === 'MODEL_A' || turn.speaker === 'USER') {
                    proScore += persuasiveness;
                } else {
                    conScore += persuasiveness;
                }
            }
        }

        // Clamp to minimum 0
        proScore = Math.max(0, proScore);
        conScore = Math.max(0, conScore);

        return { proScore, conScore };
    }

    /**
     * Check if the debate should end due to score dominance
     * Returns winner ('PRO' or 'CON') or null if no winner yet
     */
    private async checkForWinner(debateId: string, turns: any[]): Promise<string | null> {
        const { proScore, conScore } = this.calculateDebateScores(turns);
        const total = proScore + conScore;

        if (total === 0) return null;

        const proPercent = (proScore / total) * 100;
        const conPercent = (conScore / total) * 100;

        console.log(`[Debate] Score check - PRO: ${proPercent.toFixed(1)}%, CON: ${conPercent.toFixed(1)}%`);

        // If one side drops to 0% or below 5%, declare winner
        if (proPercent <= 5) {
            console.log(`[Debate] CON wins by score dominance (PRO at ${proPercent.toFixed(1)}%)`);
            await this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED, winner: 'CON' }
            });
            return 'CON';
        }

        if (conPercent <= 5) {
            console.log(`[Debate] PRO wins by score dominance (CON at ${conPercent.toFixed(1)}%)`);
            await this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED, winner: 'PRO' }
            });
            return 'PRO';
        }

        return null;
    }


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
                        id: true,
                        speaker: true,
                        content: true,
                        timestamp: true,
                        modelName: true,
                        analysis: true
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
                        id: true,
                        speaker: true,
                        content: true,
                        timestamp: true,
                        modelName: true,
                        analysis: true
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

        // GUARD: If last turn has an unacknowledged warning, block AI response
        if (lastTurn.speaker === Speaker.USER && lastTurn.analysis) {
            const analysis = lastTurn.analysis as any;
            if (analysis.warning && analysis.warning.length > 0 && !analysis.warningAccepted) {
                console.log(`[Debate] Blocked AI turn: Pending unacknowledged warning for debate ${debateId}`);
                throw new Error('PENDING_WARNING');
            }
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
        const debate = await this.prisma.debate.findUnique({
            where: { id: debateId }
        });

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
            analysis = await this.analyzeTurn(topic, lastTurnContent, content, debate?.difficulty);
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

        // Check for auto-win by score dominance
        const updatedDebate = await this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: true }
        });
        if (updatedDebate) {
            await this.checkForWinner(debateId, updatedDebate.turns);
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
        const analysis = await this.analyzeTurn(debate.topic, lastTurnContent, content, (debate as any).difficulty);

        await this.prisma.debateTurn.update({
            where: { id: newTurn.id },
            data: { analysis }
        });

        // Debug: Log analysis result
        console.log(`[Debate] User turn analysis for ${debateId}:`, JSON.stringify(analysis, null, 2));

        // Check if user conceded
        const userConceded = (analysis as any).conceded === true;
        console.log(`[Debate] User conceded check: ${userConceded} (raw value: ${(analysis as any).conceded})`);

        if (userConceded) {
            console.log(`[Debate] User conceded in debate ${debateId} - marking as FINISHED`);
            await this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED }
            });
        }

        // Check for auto-win by score dominance - ONLY if no warning is pending
        const updatedDebate = await this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: true }
        });

        const hasWarning = (analysis as any).warning && (analysis as any).warning.length > 0;
        let winner: string | null = null;
        if (updatedDebate && !hasWarning) {
            winner = await this.checkForWinner(debateId, updatedDebate.turns);
        }

        await this.cacheManager.del(`debate:${debateId}`);

        return { turn: newTurn, analysis, finished: userConceded || (winner !== null && !hasWarning), winner };
    }

    async acknowledgeWarning(debateId: string) {
        const lastTurn = await this.prisma.debateTurn.findFirst({
            where: { debateId },
            orderBy: { timestamp: 'desc' }
        });

        if (lastTurn && lastTurn.speaker === Speaker.USER && lastTurn.analysis) {
            const analysis = lastTurn.analysis as any;
            analysis.warningAccepted = true;

            await this.prisma.debateTurn.update({
                where: { id: lastTurn.id },
                data: { analysis }
            });

            // NOW check for winner since the penalty is finalized
            const updatedTurns = await this.prisma.debateTurn.findMany({
                where: { debateId },
                orderBy: { timestamp: 'asc' }
            });
            const winner = await this.checkForWinner(debateId, updatedTurns);

            await this.cacheManager.del(`debate:${debateId}`);
            return { success: true, finished: winner !== null, winner };
        }
        return { success: false, message: 'No pending warning found' };
    }
    async undoLastTurn(debateId: string) {
        const lastTurn = await this.prisma.debateTurn.findFirst({
            where: { debateId },
            orderBy: { timestamp: 'desc' }
        });

        if (lastTurn) {
            await this.prisma.debateTurn.delete({
                where: { id: lastTurn.id }
            });
            await this.cacheManager.del(`debate:${debateId}`);
            await this.cacheManager.del('debates:all');
            return { success: true };
        }
        return { success: false, message: 'No turns found to undo' };
    }

    async startDebate(topic: string, userId?: string, mode: DebateMode = DebateMode.AI_VS_AI, userRole: DebateRole = DebateRole.SPECTATOR, difficulty: DifficultyLevel = DifficultyLevel.INTERMEDIATE) {
        const debate = await this.prisma.debate.create({
            data: {
                topic,
                status: DebateStatus.ACTIVE,
                userId: userId || null,
                mode,
                userRole,
                difficulty
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

        // GUARD: If last turn has an unacknowledged warning, block AI response
        if (lastTurn.speaker === Speaker.USER && lastTurn.analysis) {
            const analysis = lastTurn.analysis as any;
            if (analysis.warning && analysis.warning.length > 0 && !analysis.warningAccepted) {
                console.log(`[Debate] Blocked AI turn: Pending unacknowledged warning for debate ${debateId}`);
                throw new Error('PENDING_WARNING');
            }
        }

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

        const context = await this.ragService.searchSimilar(lastTurn.content, 5);
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
You are debating against ${opponentDescription}. Your goal is to DEFEAT them with logic, evidence, and sharp rhetoric.

Topic: "${debate.topic}"

=== FULL DEBATE HISTORY ===
${history}

=== RELEVANT FACTS (USE THESE!) ===
${contextText || 'No additional facts available - use your own knowledge.'}

=== YOUR MISSION ===
1. READ the opponent's LAST argument carefully
2. IDENTIFY their weakest point or logical flaw
3. ATTACK that specific weakness with evidence
4. Make YOUR OWN stronger counter-claim
5. End with a POINTED QUESTION that traps them

=== RESPONSE RULES ===
- You MUST directly address what they just said
- Quote or paraphrase their claim before attacking it
- Provide at least ONE fact, statistic, or concrete example
- Be confident, witty, and slightly ruthless
- NO meta-commentary like "Here's my response" or "Let me explain"
- 100-150 WORDS

=== RESPONSE FORMAT ===
**Their Flaw:** [Quote or summarize their weakest point]
**My Attack:** [Your counter-argument with evidence]
**My Claim:** [Your stronger position]
**Challenge:** [A pointed question that puts pressure on them]

GO! Demolish their argument!
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
            analysis = await this.analyzeTurn(debate.topic, lastTurn.content, responseContent, (debate as any).difficulty);
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

    async createMultiplayerDebate(topic: string, proUserId: string, conUserId: string) {
        const debate = await this.prisma.debate.create({
            data: {
                topic,
                status: DebateStatus.ACTIVE,
                userId: proUserId,      // Pro Player
                opponentId: conUserId,  // Con Player
                mode: DebateMode.HUMAN_VS_HUMAN,
                userRole: DebateRole.PRO // Creator/Pro logic (doesn't matter much for Hvh but keeps consistency)
            },
        });

        await this.cacheManager.del('debates:all');
        await this.cacheManager.del(`debates:user:${proUserId}`);
        await this.cacheManager.del(`debates:user:${conUserId}`);

        return debate;
    }

    async processMultiplayerTurn(debateId: string, userId: string, content: string) {
        const debate = await this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: { orderBy: { timestamp: 'desc' }, take: 1 } } // Get last turn
        });

        if (!debate) throw new NotFoundException('Debate not found');
        if (debate.status === DebateStatus.FINISHED) throw new Error('Debate finished');

        // Determine Speaker Role
        let speaker: Speaker;
        if (userId === debate.userId) {
            speaker = Speaker.MODEL_A; // Pro
        } else if (userId === debate.opponentId) {
            speaker = Speaker.MODEL_B; // Con
        } else {
            throw new Error('User is not a participant in this debate');
        }

        // Save Turn
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId,
                speaker,
                content,
                modelName: 'Human User' // Or fetch username if needed
            }
        });

        // Judge the turn
        // Context: Topic + Last Turn
        const lastTurnContent = debate.turns[0]?.content || ''; // Be careful, turns[0] is the *previous* turn due to 'desc' sort

        // If it's the very first turn (Pro opening), judge against topic?
        // analyzeTurn takes (topic, opponentArg, response).
        // For first turn, opponentArg can be "The topic itself".

        const effectiveOpponentArg = lastTurnContent || `The topic is: ${debate.topic}`;

        const analysis = await this.analyzeTurn(debate.topic, effectiveOpponentArg, content);

        await this.prisma.debateTurn.update({
            where: { id: newTurn.id },
            data: { analysis }
        });

        // Check Win Condition
        const conceded = (analysis as any).conceded === true;
        if (conceded) {
            await this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED }
            });
        }

        await this.cacheManager.del(`debate:${debateId}`);

        return {
            turn: newTurn,
            analysis,
            finished: conceded
        };
    }

    private async analyzeTurn(topic: string, opponentArg: string, response: string, difficulty: DifficultyLevel = DifficultyLevel.INTERMEDIATE): Promise<any> {
        let penaltyMultiplier = 1.0;
        let judgePersonality = "standard and fair";

        if (difficulty === DifficultyLevel.BEGINNER) {
            penaltyMultiplier = 0.5;
            judgePersonality = "lenient and encouraging, focusing more on effort than perfect logic";
        } else if (difficulty === DifficultyLevel.EXPERT) {
            penaltyMultiplier = 1.5;
            judgePersonality = "ruthless and pedantic, seeking any minor flaw to destroy your argument";
        }

        const prompt = `
You are a ${judgePersonality.toUpperCase()} debate judge executing as a TOOL. You MUST return structured JSON.
Your job is to analyze this response and detect ANY violations.

Difficulty Level: ${difficulty}
Strictness Multiplier: ${penaltyMultiplier}x

Topic: "${topic}"
Opponent said: "${opponentArg}"
Response to judge: "${response}"

=== VIOLATION DETECTION (SET BOOLEANS) ===

1. OFF_TOPIC: Does the response relate to the debate topic?
   - TRUE if talking about unrelated subjects or completely ignoring context.
   - Base Penalty: -80 points
   - Scaled Penalty: -${Math.round(80 * penaltyMultiplier)} points

2. GIVING_UP: Is the speaker surrendering or conceding?
   - TRUE for: "I quit", "You win", "Ok you got me", "I give up", "GG", "Fine you're right"
   - TRUE for: "I can't argue with that", "Whatever", "I'm done", "I don't care"
   - TRUE for any admission of defeat or loss of will to continue.
   - Penalty: INSTANT LOSS (conceded = true)

3. PROVOKING: Is the response inappropriate or attacking personally?
   - TRUE for: personal insults, ad hominem attacks, profanity.
   - Base Penalty: -100 points
   - Scaled Penalty: -${Math.round(100 * penaltyMultiplier)} points + warning

4. NO_SUBSTANCE: Does the response lack any real argument?
   - TRUE for: one-word answers, emoji only, "lol", "ok", or empty responses.
   - Base Penalty: -60 points
   - Scaled Penalty: -${Math.round(60 * penaltyMultiplier)} points

5. DODGING: Did they avoid answering the opponent's direct question?
   - Base Penalty: -50 points
   - Scaled Penalty: -${Math.round(50 * penaltyMultiplier)} points

=== SCORING (0-100 each) ===
- claim_score: Quality of their main argument (0 if no real claim)
- evidence_score: Did they provide facts/examples? (0 if none)
- rebuttal_score: Did they counter opponent's points? (0 if ignored)

=== FINAL SCORE CALCULATION ===
base_score = (claim_score + evidence_score + rebuttal_score) / 3
penalties = off_topic_penalty + provoking_penalty + no_substance_penalty + dodging_penalty
final_persuasiveness = max(0, base_score + penalties)

If ANY giving_up signal: conceded = true, debate ends

=== REQUIRED OUTPUT (STRICT JSON) ===
{
    "persuasiveness": <number 0-100, can be 0 or negative after penalties>,
    "claim_score": <number 0-100>,
    "evidence_score": <number 0-100>,
    "rebuttal_score": <number 0-100>,
    "violations": {
        "off_topic": <boolean>,
        "giving_up": <boolean>,
        "provoking": <boolean>,
        "no_substance": <boolean>,
        "dodging": <boolean>
    },
    "warning": "<string, describe the violation if any, otherwise empty string>",
    "warning_level": "<string: INFO | WARNING | CRITICAL, based on severity>",
    "remediation": "<string, specific advice on how to improve the argument to fix the violation>",
    "key_point": "<one sentence summary of their argument, or 'No valid argument'>",
    "weakness": "<biggest flaw in their response>",
    "conceded": <boolean, true if violations.giving_up detected>
}

RETURN ONLY THE JSON. NO EXPLANATION.
`;

        try {
            console.log(`[Judge] Analyzing response: "${response.substring(0, 50)}..."`);
            const jsonStr = await this.llmService.generateResponse(prompt, 'llama3.2');

            // Extract JSON object using regex to handle potential markdown or extra text
            const jsonMatch = jsonStr.match(/\{[\s\S]*\}/);
            if (!jsonMatch) {
                console.error('[Judge] No JSON found in analysis response:', jsonStr);
                throw new Error('No JSON found');
            }

            const result = JSON.parse(jsonMatch[0]);

            // Ensure violations object exists
            if (!result.violations) {
                result.violations = {
                    off_topic: !!result.off_topic,
                    giving_up: !!result.giving_up || !!result.conceded,
                    provoking: !!result.provoking,
                    no_substance: !!result.no_substance,
                    dodging: !!result.dodging
                };
            }

            // Cleanup root level booleans if they exist
            delete result.off_topic;
            delete result.giving_up;
            delete result.provoking;
            delete result.no_substance;
            delete result.dodging;

            // Log violations for debugging
            if (result.violations.off_topic) console.log(`[Judge] VIOLATION: Off-topic detected`);
            if (result.violations.giving_up) console.log(`[Judge] VIOLATION: Giving up detected - CONCESSION`);
            if (result.violations.provoking) console.log(`[Judge] VIOLATION: Provoking statement detected`);
            if (result.violations.no_substance) console.log(`[Judge] VIOLATION: No substance detected`);
            if (result.violations.dodging) console.log(`[Judge] VIOLATION: Dodging detected`);

            // Ensure warning and level exists if any violation is true
            const hasViolation = Object.values(result.violations).some(v => v === true);
            if (hasViolation) {
                if (!result.warning || result.warning.trim() === "") {
                    result.warning = "The judge noticed some issues with your response.";
                }
                if (!result.warning_level) {
                    result.warning_level = result.violations.provoking ? "CRITICAL" : "WARNING";
                }
                if (!result.remediation) {
                    result.remediation = "Try to address the topic more directly and avoid personal attacks or vague statements.";
                }
            } else {
                result.warning_level = result.warning_level || "INFO";
                result.remediation = result.remediation || "";
            }

            if (result.warning) console.log(`[Judge] WARNING: ${result.warning}`);
            console.log(`[Judge] Final score: ${result.persuasiveness}, Conceded: ${result.conceded}`);

            return result;
        } catch (e) {
            console.error('[Judge] Analysis parsing failed:', e);
            return {
                persuasiveness: 50,
                claim_score: 50,
                evidence_score: 50,
                rebuttal_score: 50,
                violations: {
                    off_topic: false,
                    giving_up: false,
                    provoking: false,
                    no_substance: false,
                    dodging: false
                },
                warning: "",
                key_point: "Analysis unavailable",
                weakness: "Could not analyze",
                conceded: false
            };
        }
    }
}
