import { Injectable, InternalServerErrorException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class LlmService {
    private readonly ollamaUrl = 'http://localhost:11434/api/chat';
    private readonly model = 'llama3.2'; // 3B model

    constructor(private readonly httpService: HttpService) { }

    async generateResponse(content: string, model: string = 'llama3.2'): Promise<string> {
        try {
            const response = await firstValueFrom(
                this.httpService.post<{ message: { content: string } }>(this.ollamaUrl, {
                    model: model, // llama3.2 (Fast) or llama3 (Smart)
                    messages: [{ role: 'user', content }],
                    stream: false,
                }),
            );

            // Ollama response format: { model: '...', created_at: '...', message: { role: 'assistant', content: '...' }, ... }
            return response.data.message?.content || 'No response from AI.';
        } catch (error) {
            console.error('Ollama API Error:', error);
            throw new InternalServerErrorException('Failed to communicate with AI model');
        }
    }
}
