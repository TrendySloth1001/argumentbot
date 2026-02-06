import { Controller, Post, Body } from '@nestjs/common';
import { LlmService } from './llm.service';

@Controller('chat')
export class LlmController {
    constructor(private readonly llmService: LlmService) { }

    @Post()
    async chat(@Body('message') message: string, @Body('model') model?: string) {
        if (!message) {
            return { error: 'Message is required' };
        }
        const response = await this.llmService.generateResponse(message, model);
        return { response };
    }
}
