import { Controller, Post, Get, Body, Res, HttpStatus } from '@nestjs/common';
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
        const audioBuffer = await this.ttsService.synthesize(dto.text, dto.voice);

        res.set({
            'Content-Type': 'audio/wav',
            'Content-Length': audioBuffer.length,
            'Content-Disposition': 'attachment; filename="speech.wav"',
        });

        res.status(HttpStatus.OK).send(audioBuffer);
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
