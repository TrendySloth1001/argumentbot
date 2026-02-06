import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LlmService } from '../llm/llm.service';
import { RagService } from '../rag/rag.service';
import { ScoringService } from './scoring.service';
import { DebateStatus, Speaker } from '@prisma/client';

@Injectable()
export class DebateService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly llmService: LlmService,
        private readonly ragService: RagService,
        private readonly scoringService: ScoringService,
    ) { }

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

        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map((d) => d.content).join('\n');

        const prompt = `
        You are participating in a debate on the topic: "${debate.topic}".
        You are ${nextSpeaker} (${roleDescription}). 
        
        Your Opponent said: "${lastTurn.content}"

        Relevant Context:
        ${contextText}

        Instructions:
        1. Start your response with a concise main argument using clear language.
        2. Use bullet points for key supporting details.
        3. END your response with a dedicated section header: "### Counter Question".
        4. Under that header, ask a provocative simple question.

        Format:
        [Your Argument Here]
        
        ### Counter Question
        [Your Question Here]
        `;

        const stream = await this.llmService.generateStream(prompt, 'llama3.2');

        // We return the stream + metadata needed to save the turn later
        return {
            stream,
            debateId: debate.id,
            speaker: nextSpeaker,
            topic: debate.topic,
            lastTurnContent: lastTurn.content,
            scoringMode
        };
    }

    async saveTurn(debateId: string, speaker: Speaker, content: string, scoringMode: 'AI' | 'ALGO', topic: string, lastTurnContent: string) {
        // Create Turn
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId,
                speaker,
                content,
                modelName: 'llama3.2'
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

        return newTurn;
    }

    async startDebate(topic: string) {
        // Create the debate
        const debate = await this.prisma.debate.create({
            data: {
                topic,
                status: DebateStatus.ACTIVE,
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
            },
        });

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
        - Directly rebut the opponent's points.
        - Use strong, persuasive language.
        - END with a provocative counter-question to put the opponent on the defensive.
        - Keep it under 3 sentences.
        `;

        const responseContent = await this.llmService.generateResponse(prompt, 'llama3.2');

        // 3. Create Turn WITHOUT analysis first
        const newTurn = await this.prisma.debateTurn.create({
            data: {
                debateId: debate.id,
                speaker: nextSpeaker,
                content: responseContent,
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

    async getDebate(id: string) {
        return this.prisma.debate.findUnique({
            where: { id },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });
    }

    async getAllDebates() {
        return this.prisma.debate.findMany({
            orderBy: { createdAt: 'desc' },
            include: {
                turns: { take: 1, orderBy: { timestamp: 'desc' } } // Optional: include last turn for preview
            }
        });
    }
}
