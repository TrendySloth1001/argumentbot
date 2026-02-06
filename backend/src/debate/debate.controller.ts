import { Controller, Post, Body, Get, Param, Res, Query, UseGuards, Req } from '@nestjs/common';
import type { Response } from 'express';
import { DebateService } from './debate.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('debate')
export class DebateController {
    constructor(private readonly debateService: DebateService) { }

    @UseGuards(AuthGuard('jwt'))
    @Post('start')
    async startDebate(@Body('topic') topic: string, @Req() req) {
        return this.debateService.startDebate(topic, req.user.userId);
    }

    @Post(':id/next')
    async nextTurn(@Param('id') id: string, @Body('scoringMode') scoringMode?: 'AI' | 'ALGO') {
        return this.debateService.processTurn(id, scoringMode);
    }

    @Get(':id/stream')
    async streamTurn(@Param('id') id: string, @Query('scoringMode') scoringMode: 'AI' | 'ALGO' = 'AI', @Res() res: Response) {
        const { stream, debateId, speaker, topic, lastTurnContent, modelName } = await this.debateService.processTurnStream(id, scoringMode);

        if (!stream) {
            res.end();
            return;
        }

        res.setHeader('Content-Type', 'text/event-stream');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('Connection', 'keep-alive');

        let fullContent = '';
        const reader = stream.getReader();

        try {
            while (true) {
                const { done, value } = await reader.read();
                if (done) break;

                const chunk = new TextDecoder().decode(value);
                const lines = chunk.split('\n').filter(line => line.trim() !== '');

                for (const line of lines) {
                    try {
                        const json = JSON.parse(line);
                        if (json.message?.content) {
                            const content = json.message.content;
                            fullContent += content;
                            res.write(`data: ${JSON.stringify({ content, speaker })}\n\n`);
                        }
                        if (json.done) {
                            if (debateId && speaker && topic && lastTurnContent && modelName) {
                                await this.debateService.saveTurn(debateId, speaker, fullContent, scoringMode, topic, lastTurnContent, modelName);
                            }
                            res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
                        }
                    } catch (e) {
                        // ignore parse error for partial chunks
                    }
                }
            }
        } catch (error) {
            console.error('Streaming error', error);
        } finally {
            res.end();
        }
    }

    @Get(':id')
    async getDebate(@Param('id') id: string) {
        return this.debateService.getDebate(id);
    }

    // Get debates for current user only
    @UseGuards(AuthGuard('jwt'))
    @Get()
    async getAllDebates(@Req() req) {
        return this.debateService.getDebatesByUser(req.user.userId);
    }
}
