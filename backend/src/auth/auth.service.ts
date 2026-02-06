import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { UsersService } from '../users/users.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import * as argon2 from 'argon2';
import { uniqueNamesGenerator, adjectives, colors, animals } from 'unique-names-generator';


@Injectable()
export class AuthService {
    constructor(
        private usersService: UsersService,
        private jwtService: JwtService,
    ) { }

    async register(registerDto: RegisterDto) {
        // Check if user exists
        const existingUser = await this.usersService.findOne(registerDto.email);
        if (existingUser) {
            throw new ConflictException('Email already in use');
        }

        // Hash password
        const hashedPassword = await argon2.hash(registerDto.password);

        // Generate random username
        const username = uniqueNamesGenerator({
            dictionaries: [adjectives, colors, animals],
            separator: '',
            style: 'capital', // e.g. HappyRedLion
            length: 3,
        });

        // Create user
        const user = await this.usersService.create({
            email: registerDto.email,
            username: username,
            passwordHash: hashedPassword,
        });

        const payload = { sub: user.id, email: user.email, username: user.username };
        const token = this.jwtService.sign(payload);

        // Return user and token
        return {
            id: user.id,
            email: user.email,
            username: user.username,
            createdAt: user.createdAt,
            token,
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

        const payload = { sub: user.id, email: user.email, username: user.username };
        const token = this.jwtService.sign(payload);

        return {
            message: 'Login successful',
            user: {
                id: user.id,
                email: user.email,
                username: user.username,
            },
            token,
        };
    }
}
