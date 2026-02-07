import { Injectable, HttpException, HttpStatus } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { StorageService } from '../storage/storage.service';

export interface Voice {
    id: string;
    name: string;
    language: string;
}

export interface SynthesizeResult {
    audioUrl: string;
    cached: boolean;
}

@Injectable()
export class TtsService {
    private readonly ttsServiceUrl: string;

    constructor(
        private readonly httpService: HttpService,
        private readonly configService: ConfigService,
        private readonly storageService: StorageService,
    ) {
        this.ttsServiceUrl = this.configService.get<string>('TTS_SERVICE_URL') || 'http://localhost:5500';
    }

    async synthesize(text: string, voice?: string): Promise<Buffer> {
        // Generate cache key
        const cacheKey = this.storageService.generateCacheKey(text + (voice || ''));

        // Check if already cached in MinIO
        try {
            const exists = await this.storageService.exists(cacheKey);
            if (exists) {
                console.log(`TTS cache hit: ${cacheKey}`);
                return await this.storageService.download(cacheKey);
            }
        } catch (error) {
            // MinIO not available, continue with direct synthesis
            console.log('MinIO not available, synthesizing directly');
        }

        // Synthesize audio
        const audioBuffer = await this.synthesizeDirect(text, voice);

        // Cache in MinIO (non-blocking)
        this.storageService.upload(cacheKey, audioBuffer).catch(err => {
            console.log('Failed to cache TTS audio:', err.message);
        });

        return audioBuffer;
    }

    async synthesizeWithUrl(text: string, voice?: string): Promise<SynthesizeResult> {
        const cacheKey = this.storageService.generateCacheKey(text + (voice || ''));

        // Check cache
        try {
            const exists = await this.storageService.exists(cacheKey);
            if (exists) {
                const audioUrl = await this.storageService.getSignedUrl(cacheKey);
                return { audioUrl, cached: true };
            }
        } catch {
            // MinIO not available
        }

        // Synthesize and cache
        const audioBuffer = await this.synthesizeDirect(text, voice);

        try {
            await this.storageService.upload(cacheKey, audioBuffer);
            const audioUrl = await this.storageService.getSignedUrl(cacheKey);
            return { audioUrl, cached: false };
        } catch {
            // Return direct buffer if MinIO fails
            throw new HttpException('Storage service unavailable', HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    private async synthesizeDirect(text: string, voice?: string): Promise<Buffer> {
        try {
            const response = await firstValueFrom(
                this.httpService.post(
                    `${this.ttsServiceUrl}/synthesize`,
                    { text, voice },
                    { responseType: 'arraybuffer' }
                )
            );
            return Buffer.from(response.data);
        } catch (error) {
            if (error.response) {
                throw new HttpException(
                    error.response.data?.detail || 'TTS synthesis failed',
                    error.response.status || HttpStatus.INTERNAL_SERVER_ERROR
                );
            }
            throw new HttpException('TTS service unavailable', HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    async getVoices(): Promise<Voice[]> {
        try {
            const response = await firstValueFrom(
                this.httpService.get(`${this.ttsServiceUrl}/voices`)
            );
            return response.data.voices;
        } catch (error) {
            throw new HttpException('Failed to fetch voices', HttpStatus.SERVICE_UNAVAILABLE);
        }
    }

    async healthCheck(): Promise<boolean> {
        try {
            const response = await firstValueFrom(
                this.httpService.get(`${this.ttsServiceUrl}/health`)
            );
            return response.data.status === 'healthy';
        } catch {
            return false;
        }
    }
}
