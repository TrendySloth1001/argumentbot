import { Module } from '@nestjs/common';
import { PolicyController } from './policy.controller';

@Module({
    controllers: [PolicyController],
})
export class PolicyModule { }
