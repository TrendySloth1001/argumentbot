import { Module } from '@nestjs/common';
import { RagService } from './rag.service';
import { PrismaModule } from '../prisma/prisma.module';
import { HttpModule } from '@nestjs/axios';

@Module({
    imports: [PrismaModule, HttpModule],
    providers: [RagService],
    exports: [RagService],
})
export class RagModule { }
