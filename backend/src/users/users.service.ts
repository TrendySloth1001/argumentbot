import { Injectable, Inject } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { User, Prisma } from '@prisma/client';
import { CACHE_MANAGER } from '@nestjs/cache-manager';
import type { Cache } from 'cache-manager';

@Injectable()
export class UsersService {
    constructor(
        private prisma: PrismaService,
        @Inject(CACHE_MANAGER) private cacheManager: Cache,
    ) { }

    async create(data: Prisma.UserCreateInput): Promise<User> {
        return this.prisma.user.create({
            data,
        });
    }

    async findOne(email: string): Promise<User | null> {
        const cacheKey = `user:${email}`;
        const cachedUser = await this.cacheManager.get<User>(cacheKey);
        if (cachedUser) {
            return cachedUser;
        }

        const user = await this.prisma.user.findUnique({
            where: { email },
        });

        if (user) {
            await this.cacheManager.set(cacheKey, user, 3600000); // 1 hour TTL (ms)
        }

        return user;
    }
    async update(userId: string, data: Prisma.UserUpdateInput): Promise<User> {
        const user = await this.prisma.user.update({
            where: { id: userId },
            data,
        });

        // Invalidate cache
        await this.cacheManager.del(`user:${user.email}`);

        return user;
    }
}
