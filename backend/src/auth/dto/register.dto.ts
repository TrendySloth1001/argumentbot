import { IsEmail, IsNotEmpty, IsString, MinLength } from 'class-validator';

export class RegisterDto {
    @IsEmail({}, { message: 'Invalid email address' })
    email: string;

    @IsString()
    @IsNotEmpty()
    @MinLength(8, { message: 'Password must be at least 8 characters long' })
    password: string;
}
