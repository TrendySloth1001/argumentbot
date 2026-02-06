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

    // ... (rest of methods)

    async getDebate(id: string) {
        const cacheKey = `debate:${id}`;
        const cached = await this.cacheManager.get(cacheKey);
        if (cached) return cached;

        const debate = await this.prisma.debate.findUnique({
            where: { id },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });

        if (debate) await this.cacheManager.set(cacheKey, debate, 600000); // 10 mins
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

    // Get debates for a specific user only
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
        const roleDescription = nextSpeaker === Speaker.MODEL_A ? 'The Proponent' : 'The Opponent';

        // Dynamic Model Selection
        // MODEL_A = Proponent (Llama 3.2: Fast, Consistent)
        // MODEL_B = Opponent (Gemma 2:2b: Creative, Different Tone)
        const activeModel = nextSpeaker === Speaker.MODEL_A ? 'llama3.2' : 'gemma2:2b';

        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map((d) => d.content).join('\n');

        const prompt = `
        You are participating in a debate on the topic: "${debate.topic}".
        You are ${nextSpeaker} (${roleDescription}). 
        
        Your Opponent said: "${lastTurn.content}"

        Relevant Context:
        ${contextText}

        Instructions:
        1. FIRST, start with a section header: "## Answer".
        2. Under "## Answer", directly address the opponent's main point or question.
        3. Then, provide your own concise main argument using clear language.
        4. END your response with a dedicated section header: "### Counter Question".
        5. Under that header, ask a provocative simple question to the opponent.
        6. CRITICAL: Keep your entire response UNDER 100 WORDS.

        Format:
        ## Answer
        [Direct Answer/Rebuttal]

        [Main Argument]
        
        ### Counter Question
        [Your Question Here]
        `;

        const stream = await this.llmService.generateStream(prompt, activeModel);

        // We return the stream + metadata needed to save the turn later
        return {
            stream,
            debateId: debate.id,
            speaker: nextSpeaker,
            topic: debate.topic,
            lastTurnContent: lastTurn.content,
            scoringMode,
            modelName: activeModel // Pass the chosen model name
        };
    }

    async saveTurn(debateId: string, speaker: Speaker, content: string, scoringMode: 'AI' | 'ALGO', topic: string, lastTurnContent: string, modelName: string) {
        // Create Turn
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId,
                speaker,
                content,
                modelName: modelName
            },
        });

        // Analyze
        let analysis;
        if (scoringMode === 'ALGO') {
            analysis = this.scoringService.calculateScore(content, topic);
        } else {
            analysis = await this.analyzeTurn(topic, lastTurnContent, content);
        }

        // Update Turn
        await this.prisma.debateTurn.update({
            where: { id: newTurn.id },
            data: { analysis },
        });

        await this.cacheManager.del(`debate:${debateId}`);
        await this.cacheManager.del('debates:all');

        return newTurn;
    }

    async startDebate(topic: string, userId?: string) {
        // Create the debate
        const debate = await this.prisma.debate.create({
            data: {
                topic,
                status: DebateStatus.ACTIVE,
                userId: userId || null,
            },
        });

        // Initialize with an opening statement from Model A
        const context = await this.ragService.searchSimilar(topic);
        const contextText = context.map(c => c.content).join('\n');

        const prompt = `
        You are participating in a debate on the topic: "${topic}".
        You are Speaker A (The Proponent). 
        
        Relevant Facts:
        ${contextText}

        Please provide your opening argument supporting the topic. Keep it concise (under 3 sentences).
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

        await this.cacheManager.del('debates:all'); // Invalidate list
        await this.cacheManager.del('debates:all'); // Invalidate list
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
        const roleDescription = nextSpeaker === Speaker.MODEL_A ? 'The Proponent' : 'The Opponent';

        // Multi-model for non-streaming
        const activeModel = nextSpeaker === Speaker.MODEL_A ? 'llama3.2' : 'gemma2:2b';

        // 1. Retrieve relevant context (RAG)
        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map((d) => d.content).join('\n');

        // 2. Generate Response
        const prompt = `
        You are participating in a debate on the topic: "${debate.topic}".
        You are ${nextSpeaker} (${roleDescription}). 
        
        Your Opponent said: "${lastTurn.content}"

        Relevant Context:
        ${contextText}

        Instructions:
        - Start with "## Answer" to rebut the opponent.
        - Use strong, persuasive language for your argument.
        - END with "### Counter Question" to ask a provocative question.
        - CRITICAL: Keep response UNDER 100 WORDS.
        `;

        const responseContent = await this.llmService.generateResponse(prompt, activeModel);

        // 3. Create Turn WITHOUT analysis first
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId: debate.id,
                speaker: nextSpeaker,
                content: responseContent,
                modelName: activeModel
            },
        });

        // 4. Analyze Turn (Hybrid)
        let analysis;
        if (scoringMode === 'ALGO') {
            analysis = this.scoringService.calculateScore(responseContent, debate.topic);
        } else {
            // We analyze the NEW turn in context of the debate
            analysis = await this.analyzeTurn(debate.topic, lastTurn.content, responseContent);
        }

        // 5. Update Turn with Analysis
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
        Act as an impartial debate judge. Analyze the following exchange:
        Topic: "${topic}"
        Opponent Argument: "${opponentArg}"
        Response: "${response}"

        Evaluate the Response based on:
        1. Persuasiveness (0-100)
        2. Rebuttal Effectiveness (0-100) - Did they address the point?
        3. Counter-Question Quality (0-100) - Is it a strong question?

        Output ONLY valid JSON:
        {
            "persuasiveness": number,
            "rebuttal_score": number,
            "question_score": number,
            "key_point": "string summary of the main point"
        }
        `;

        try {
            const jsonStr = await this.llmService.generateResponse(prompt, 'llama3.2');
            // Clean up markdown code blocks if present
            const cleanJson = jsonStr.replace(/```json/g, '').replace(/```/g, '').trim();
            return JSON.parse(cleanJson);
        } catch (e) {
            console.error('Analysis failed', e);
            return { persuasiveness: 50, rebuttal_score: 50, question_score: 50, key_point: "Analysis unavailable" };
        }
    }

}
