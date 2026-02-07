import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
    constructor(
        configService: ConfigService,
        private prisma: PrismaService,
    ) {
        super({
            jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
            ignoreExpiration: false,
            secretOrKey: configService.get<string>('JWT_SECRET') || 'super_secret',
        });
    }

    async validate(payload: any) {
        // Fetch fresh user data from database to get current avatarUrl
        const user = await this.prisma.user.findUnique({
            where: { id: payload.sub },
            select: {
                id: true,
                email: true,
                username: true,
                avatarUrl: true,
            },
        });

        if (!user) {
            return null;
        }

        return {
            userId: user.id,
            email: user.email,
            username: user.username,
            avatarUrl: user.avatarUrl,
        };
    }
}
