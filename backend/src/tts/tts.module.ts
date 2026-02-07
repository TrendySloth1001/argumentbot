import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { TtsController } from './tts.controller';
import { TtsService } from './tts.service';

@Module({
    imports: [
        HttpModule,
        ConfigModule,
    ],
    controllers: [TtsController],
    providers: [TtsService],
    exports: [TtsService],
})
export class TtsModule { }
