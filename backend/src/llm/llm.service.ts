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
                }, {
                    timeout: 120000, // 120 seconds for slow LLM analysis
                }),
            );

            // Ollama response format: { model: '...', created_at: '...', message: { role: 'assistant', content: '...' }, ... }
            return response.data.message?.content || 'No response from AI.';
        } catch (error) {
            console.error('Ollama API Error:', error);
            throw new InternalServerErrorException('Failed to communicate with AI model');
        }
    }

    /**
     * Generate response using full conversation history for better context.
     * Messages should be in format: [{ role: 'system' | 'user' | 'assistant', content: string }]
     */
    async generateChatResponse(
        messages: Array<{ role: 'system' | 'user' | 'assistant'; content: string }>,
        model: string = 'llama3.2'
    ): Promise<string> {
        try {
            console.log(`[LLM] Generating chat response with ${messages.length} messages using ${model}`);
            const response = await firstValueFrom(
                this.httpService.post<{ message: { content: string } }>(this.ollamaUrl, {
                    model: model,
                    messages: messages,
                    stream: false,
                    options: {
                        num_ctx: 8192, // Increase context window
                        temperature: 0.7,
                    },
                }, {
                    timeout: 120000,
                }),
            );

            return response.data.message?.content || 'No response from AI.';
        } catch (error) {
            console.error('Ollama Chat API Error:', error);
            throw new InternalServerErrorException('Failed to communicate with AI model');
        }
    }
    async generateStream(content: string, model: string = 'llama3.2'): Promise<any> {
        try {
            const response = await fetch(this.ollamaUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    model: model,
                    messages: [{ role: 'user', content }],
                    stream: true,
                }),
            });

            if (response.status !== 200) {
                throw new Error(`Failed to fetch from Ollama: ${response.statusText}`);
            }

            if (!response.body) throw new Error('ReadableStream not supported in this environment');
            return response.body;

        } catch (error) {
            console.warn(`Primary model ${model} failed, trying fallback to llama3.2...`, error);
            if (model !== 'llama3.2') {
                // Fallback recursion
                return this.generateStream(content, 'llama3.2');
            }
            console.error('Ollama Stream Error:', error);
            throw new InternalServerErrorException('Failed to stream from AI model');
        }
    }
}
