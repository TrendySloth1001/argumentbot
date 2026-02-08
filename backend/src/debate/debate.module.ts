import { Module } from '@nestjs/common';
import { DebateController } from './debate.controller';
import { DebateService } from './debate.service';
import { PrismaModule } from '../prisma/prisma.module';
import { LlmModule } from '../llm/llm.module';
import { RagModule } from '../rag/rag.module';
import { ScoringService } from './scoring.service';

import { DebateGateway } from '../gateways/debate.gateway';
import { MatchmakingGateway } from '../gateways/matchmaking.gateway';

@Module({
    imports: [PrismaModule, LlmModule, RagModule],
    controllers: [DebateController],
    providers: [DebateService, ScoringService, DebateGateway, MatchmakingGateway],
    exports: [DebateService] // Exporting it just in case
})
export class DebateModule { }
