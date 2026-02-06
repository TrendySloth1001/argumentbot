import { Module } from '@nestjs/common';
import { DebateController } from './debate.controller';
import { DebateService } from './debate.service';
import { PrismaModule } from '../prisma/prisma.module';
import { LlmModule } from '../llm/llm.module';
import { RagModule } from '../rag/rag.module';
import { ScoringService } from './scoring.service';

@Module({
    imports: [PrismaModule, LlmModule, RagModule],
    controllers: [DebateController],
    providers: [DebateService, ScoringService],
})
export class DebateModule { }
