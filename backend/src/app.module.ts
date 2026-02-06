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

@Module({
  imports: [ConfigModule.forRoot({ isGlobal: true }), UsersModule, AuthModule, PrismaModule, LlmModule, RagModule, DebateModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule { }
