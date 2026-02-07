import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
    S3Client,
    PutObjectCommand,
    GetObjectCommand,
    HeadObjectCommand,
    CreateBucketCommand,
    HeadBucketCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { Readable } from 'stream';

@Injectable()
export class StorageService implements OnModuleInit {
    private s3Client: S3Client;
    private readonly bucket: string;

    constructor(private readonly configService: ConfigService) {
        const endpoint = this.configService.get<string>('MINIO_ENDPOINT') || 'http://localhost:9000';
        const accessKey = this.configService.get<string>('MINIO_ACCESS_KEY') || 'minioadmin';
        const secretKey = this.configService.get<string>('MINIO_SECRET_KEY') || 'minioadmin';
        this.bucket = this.configService.get<string>('MINIO_BUCKET') || 'argumentbot-audio';

        this.s3Client = new S3Client({
            endpoint,
            region: 'us-east-1', // Required but ignored for MinIO
            credentials: {
                accessKeyId: accessKey,
                secretAccessKey: secretKey,
            },
            forcePathStyle: true, // Required for MinIO
        });
    }

    async onModuleInit() {
        // Ensure bucket exists on startup
        try {
            await this.s3Client.send(new HeadBucketCommand({ Bucket: this.bucket }));
        } catch (error) {
            if (error.name === 'NotFound' || error.$metadata?.httpStatusCode === 404) {
                await this.s3Client.send(new CreateBucketCommand({ Bucket: this.bucket }));
                console.log(`Created bucket: ${this.bucket}`);
            }
        }
    }

    async upload(key: string, buffer: Buffer, contentType = 'audio/wav'): Promise<string> {
        await this.s3Client.send(new PutObjectCommand({
            Bucket: this.bucket,
            Key: key,
            Body: buffer,
            ContentType: contentType,
        }));

        return key;
    }

    async download(key: string): Promise<Buffer> {
        const response = await this.s3Client.send(new GetObjectCommand({
            Bucket: this.bucket,
            Key: key,
        }));

        const stream = response.Body as Readable;
        const chunks: Buffer[] = [];

        for await (const chunk of stream) {
            chunks.push(Buffer.from(chunk));
        }

        return Buffer.concat(chunks);
    }

    async exists(key: string): Promise<boolean> {
        try {
            await this.s3Client.send(new HeadObjectCommand({
                Bucket: this.bucket,
                Key: key,
            }));
            return true;
        } catch {
            return false;
        }
    }

    async getSignedUrl(key: string, expiresIn = 3600): Promise<string> {
        const command = new GetObjectCommand({
            Bucket: this.bucket,
            Key: key,
        });

        return getSignedUrl(this.s3Client, command, { expiresIn });
    }

    generateCacheKey(text: string): string {
        // Create a hash of the text for cache key
        const crypto = require('crypto');
        const hash = crypto.createHash('sha256').update(text).digest('hex');
        return `tts/${hash.substring(0, 16)}.wav`;
    }
}
