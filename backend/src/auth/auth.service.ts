import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import * as argon2 from 'argon2';

@Injectable()
export class AuthService {
    constructor(private usersService: UsersService) { }

    async register(registerDto: RegisterDto) {
        // Check if user exists
        const existingUser = await this.usersService.findOne(registerDto.email);
        if (existingUser) {
            throw new ConflictException('Email already in use');
        }

        // Hash password
        const hashedPassword = await argon2.hash(registerDto.password);

        // Create user
        const user = await this.usersService.create({
            email: registerDto.email,
            passwordHash: hashedPassword,
        });

        // Return user without password hash
        return {
            id: user.id,
            email: user.email,
            createdAt: user.createdAt,
        };
    }

    async login(loginDto: LoginDto) {
        const user = await this.usersService.findOne(loginDto.email);
        if (!user) {
            throw new UnauthorizedException('Invalid credentials');
        }

        const isPasswordValid = await argon2.verify(user.passwordHash, loginDto.password);
        if (!isPasswordValid) {
            throw new UnauthorizedException('Invalid credentials');
        }

        return {
            message: 'Login successful',
            user: {
                id: user.id,
                email: user.email,
            },
        };
    }
}
