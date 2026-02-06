import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LlmService } from '../llm/llm.service';
import { RagService } from '../rag/rag.service';
import { DebateStatus, Speaker } from '@prisma/client';

@Injectable()
export class DebateService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly llmService: LlmService,
        private readonly ragService: RagService,
    ) { }

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

    async processTurn(debateId: string) {
        const debate = await this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });

        if (!debate) throw new NotFoundException('Debate not found');
        if (debate.status === DebateStatus.FINISHED) return debate;

        const lastTurn = debate.turns[debate.turns.length - 1];
        const nextSpeaker = lastTurn.speaker === Speaker.MODEL_A ? Speaker.MODEL_B : Speaker.MODEL_A;
        const roleDescription = nextSpeaker === Speaker.MODEL_A ? 'The Proponent' : 'The Opponent';

        // Stop after 6 turns for now
        if (debate.turns.length >= 6) {
            await this.prisma.debate.update({
                where: { id: debateId },
                data: { status: DebateStatus.FINISHED },
            });
            return debate;
        }

        const context = await this.ragService.searchSimilar(lastTurn.content);
        const contextText = context.map(c => c.content).join('\n');

        const history = debate.turns.map(t => `${t.speaker}: ${t.content}`).join('\n');

        const prompt = `
        You are participating in a debate on the topic: "${debate.topic}".
        You are ${nextSpeaker} (${roleDescription}). 
        
        Debate History:
        ${history}

        Relevant Facts:
        ${contextText}

        Please provide your counter-argument or rebuttal to the last point. Keep it concise (under 3 sentences). 
        Address the previous speaker's points directly.
        `;

        const response = await this.llmService.generateResponse(prompt);

        await this.prisma.debateTurn.create({
            data: {
                debateId: debateId,
                speaker: nextSpeaker,
                content: response,
            },
        });

        return this.prisma.debate.findUnique({
            where: { id: debateId },
            include: { turns: { orderBy: { timestamp: 'asc' } } },
        });
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
