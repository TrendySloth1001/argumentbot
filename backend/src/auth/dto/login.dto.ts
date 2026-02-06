import { IsEmail, IsNotEmpty, IsString } from 'class-validator';

export class LoginDto {
    @IsEmail({}, { message: 'Invalid email address' })
    email: string;

    @IsString()
    @IsNotEmpty()
    password: string;
}
