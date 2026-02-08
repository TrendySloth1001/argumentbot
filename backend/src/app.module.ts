import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { UsersModule } from './users/users.module';
import { AuthModule } from './auth/auth.module';
import { PrismaModule } from './prisma/prisma.module';
import { LlmModule } from './llm/llm.module';
import { RagModule } from './rag/rag.module';
import { DebateModule } from './debate/debate.module';
import { FeedModule } from './feed/feed.module';
import { PolicyModule } from './policy/policy.module';
import { TtsModule } from './tts/tts.module';
import { StorageModule } from './storage/storage.module';
import { CacheModule } from '@nestjs/cache-manager';

import { SttGateway } from './gateways/stt.gateway';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    CacheModule.register({ isGlobal: true }),
    StorageModule,
    UsersModule,
    AuthModule,
    PrismaModule,
    LlmModule,
    RagModule,
    DebateModule,
    FeedModule,
    PolicyModule,
    TtsModule,
  ],
  controllers: [AppController],
  providers: [AppService, SttGateway],
})
export class AppModule { }

