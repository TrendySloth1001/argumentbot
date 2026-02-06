import { Controller, Post, Body, Get, Query, Param, UseGuards, Req } from '@nestjs/common';
import { FeedService } from './feed.service';
import { AuthGuard } from '@nestjs/passport';

@Controller('feed')
export class FeedController {
    constructor(private readonly feedService: FeedService) { }

    @UseGuards(AuthGuard('jwt'))
    @Post('posts')
    async createPost(@Req() req, @Body() body: { debateId: string; title: string; description?: string }) {
        return this.feedService.createPost(req.user.userId, body.debateId, body.title, body.description);
    }

    @Get('posts')
    async getFeed(@Query('cursor') cursor?: string, @Query('limit') limit?: string) {
        return this.feedService.getFeed(cursor, limit ? parseInt(limit) : 10);
    }
    // ...
    @UseGuards(AuthGuard('jwt'))
    @Post('posts/:id/like')
    async toggleLike(@Param('id') id: string, @Req() req) {
        return this.feedService.toggleLike(id, req.user.userId);
    }

    @UseGuards(AuthGuard('jwt'))
    @Post('posts/:id/comments')
    async addComment(@Param('id') id: string, @Req() req, @Body() body: { content: string }) {
        return this.feedService.addComment(id, req.user.userId, body.content);
    }

    @Get('posts/:id/comments')
    async getComments(@Param('id') id: string) {
        return this.feedService.getComments(id);
    }
}
