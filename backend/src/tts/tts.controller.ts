import { Controller, Post, Get, Body, Res, HttpStatus, Query } from '@nestjs/common';
import { TtsService } from './tts.service';
import type { Response } from 'express';

class SynthesizeDto {
    text: string;
    voice?: string;
}

@Controller('tts')
export class TtsController {
    constructor(private readonly ttsService: TtsService) { }

    @Post('synthesize')
    async synthesize(@Body() dto: SynthesizeDto, @Res() res: Response) {
        console.warn(`[TTS Controller] BLOCKING synthesize called for: ${dto.text.substring(0, 20)}...`);
        const audioBuffer = await this.ttsService.synthesize(dto.text, dto.voice);

        res.set({
            'Content-Type': 'audio/wav',
            'Content-Length': audioBuffer.length,
            'Content-Disposition': 'attachment; filename="speech.wav"',
        });

        res.status(HttpStatus.OK).send(audioBuffer);
    }

    @Post('synthesize/stream')
    async synthesizeStream(@Body() dto: SynthesizeDto, @Res() res: Response) {
        const stream = await this.ttsService.synthesizeStream(dto.text, dto.voice);
        res.set({
            'Content-Type': 'audio/wav',
            'Transfer-Encoding': 'chunked',
            'X-Accel-Buffering': 'no',
        });
        stream.pipe(res);
    }

    @Get('synthesize/stream')
    async synthesizeStreamGet(@Query('text') text: string, @Query('voice') voice: string, @Res() res: Response) {
        if (!text) {
            res.status(HttpStatus.BAD_REQUEST).send('Text is required');
            return;
        }
        const stream = await this.ttsService.synthesizeStream(text, voice);
        res.set({
            'Content-Type': 'audio/wav',
            'Transfer-Encoding': 'chunked',
            'X-Accel-Buffering': 'no',
        });
        stream.pipe(res);
    }

    @Get('voices')
    async getVoices() {
        return this.ttsService.getVoices();
    }

    @Get('health')
    async health() {
        const isHealthy = await this.ttsService.healthCheck();
        return {
            status: isHealthy ? 'healthy' : 'unhealthy',
            service: 'tts-proxy'
        };
    }
}
