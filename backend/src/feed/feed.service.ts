import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FeedService {
    constructor(private readonly prisma: PrismaService) { }

    async createPost(userId: string, debateId: string, title: string, description?: string) {
        // Verify debate exists
        const debate = await this.prisma.debate.findUnique({ where: { id: debateId } });
        if (!debate) throw new NotFoundException('Debate not found');

        try {
            return await this.prisma.post.create({
                data: {
                    title,
                    description,
                    authorId: userId,
                    debateId: debateId,
                },
                include: {
                    author: { select: { username: true, avatarUrl: true } },
                    debate: true,
                },
            });
        } catch (error) {
            if (error.code === 'P2003') { // Foreign key constraint failed
                throw new NotFoundException('User or Debate not found. Please try logging out and in again.');
            }
            throw error;
        }
    }

    async getFeed(cursor?: string, limit: number = 10) {
        const posts = await this.prisma.post.findMany({
            take: limit,
            skip: cursor ? 1 : 0,
            cursor: cursor ? { id: cursor } : undefined,
            orderBy: { createdAt: 'desc' },
            include: {
                author: { select: { username: true, avatarUrl: true } },
                debate: {
                    include: {
                        turns: { orderBy: { timestamp: 'asc' } } // Return all turns
                    }
                },
            },
        });

        return {
            posts,
            nextCursor: posts.length === limit ? posts[posts.length - 1].id : null,
        };
    }

    async toggleLike(postId: string, userId: string) {
        const existingLike = await this.prisma.like.findUnique({
            where: { userId_postId: { userId, postId } },
        });

        if (existingLike) {
            // Unlike
            await this.prisma.$transaction([
                this.prisma.like.delete({ where: { userId_postId: { userId, postId } } }),
                this.prisma.post.update({
                    where: { id: postId },
                    data: { likeCount: { decrement: 1 } },
                }),
            ]);
            return { liked: false };
        } else {
            // Like
            await this.prisma.$transaction([
                this.prisma.like.create({ data: { userId, postId } }),
                this.prisma.post.update({
                    where: { id: postId },
                    data: { likeCount: { increment: 1 } },
                }),
            ]);
            return { liked: true };
        }
    }

    async addComment(postId: string, userId: string, content: string) {
        const comment = await this.prisma.comment.create({
            data: {
                content,
                authorId: userId,
                postId,
            },
            include: {
                author: { select: { username: true, avatarUrl: true } }
            }
        });

        // Update post comment count
        await this.prisma.post.update({
            where: { id: postId },
            data: { commentCount: { increment: 1 } }
        });

        return comment;
    }

    async getComments(postId: string) {
        return this.prisma.comment.findMany({
            where: { postId },
            orderBy: { createdAt: 'asc' },
            include: {
                author: { select: { username: true, avatarUrl: true } }
            }
        });
    }
}
