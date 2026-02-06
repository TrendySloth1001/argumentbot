import { Controller, Post, Body, Get, Param, Put } from '@nestjs/common';
import { DebateService } from './debate.service';

@Controller('debate')
export class DebateController {
    constructor(private readonly debateService: DebateService) { }

    @Post('start')
    async startDebate(@Body('topic') topic: string) {
        return this.debateService.startDebate(topic);
    }

    @Post(':id/next')
    async nextTurn(@Param('id') id: string) {
        return this.debateService.processTurn(id);
    }

    @Get(':id')
    async getDebate(@Param('id') id: string) {
        return this.debateService.getDebate(id);
    }

    @Get()
    async getAllDebates() {
        return this.debateService.getAllDebates();
    }
}
