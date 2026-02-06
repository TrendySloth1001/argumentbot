import { Controller, Patch, Body, UseGuards, Req } from '@nestjs/common';
import { UsersService } from './users.service';
import { AuthGuard } from '@nestjs/passport'; // Use 'jwt' strategy directly or import JwtAuthGuard if created
import { User } from '@prisma/client';

@Controller('users')
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @UseGuards(AuthGuard('jwt'))
    @Patch('profile')
    async updateProfile(@Req() req, @Body() body: { avatarUrl?: string }) {
        return this.usersService.update(req.user.userId, {
            avatarUrl: body.avatarUrl,
        });
    }
}
