import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { HttpService } from '@nestjs/axios';
import { firstValueFrom } from 'rxjs';

@Injectable()
export class RagService {
    private readonly logger = new Logger(RagService.name);
    private readonly ollamaUrl = 'http://localhost:11434/api/embeddings';
    private readonly model = 'llama3.2'; // Ensure this model is pulled and running

    constructor(
        private readonly prisma: PrismaService,
        private readonly httpService: HttpService,
    ) { }

    async embedText(text: string): Promise<number[]> {
        if (!text || text.trim().length === 0) return [];
        try {
            const response = await firstValueFrom(
                this.httpService.post<{ embedding: number[] }>(this.ollamaUrl, {
                    model: this.model,
                    prompt: text,
                    stream: false,
                }),
            );
            return response.data.embedding;
        } catch (error) {
            this.logger.error(`Failed to generate embedding for text: ${text.substring(0, 50)}...`, error);
            throw new Error('Embedding generation failed');
        }
    }

    async ingestDocument(content: string) {
        const chunks = content.split('\n\n').filter(c => c.trim().length > 0);

        for (const chunk of chunks) {
            try {
                const embedding = await this.embedText(chunk);
                if (!embedding || embedding.length === 0) continue;

                // Ensure strict casting to vector
                await this.prisma.$executeRaw`
                    INSERT INTO "Document" ("id", "content", "embedding", "createdAt")
                    VALUES (gen_random_uuid(), ${chunk}, ${embedding}::vector, NOW());
                `;
            } catch (e) {
                this.logger.error(`Failed to ingest chunk: ${chunk.substring(0, 30)}...`, e);
            }
        }
    }

    async searchSimilar(query: string, limit: number = 3): Promise<{ content: string; similarity: number }[]> {
        try {
            const embedding = await this.embedText(query);
            if (!embedding || embedding.length === 0) return [];

            const vectorString = `[${embedding.join(',')}]`;

            // Use cosine similarity (1 - distance)
            // The <=> operator returns cosine distance
            const results = await this.prisma.$queryRaw<{ content: string; similarity: number }[]>`
                SELECT content, 1 - (embedding <=> ${vectorString}::vector) as similarity
                FROM "Document"
                WHERE 1 - (embedding <=> ${vectorString}::vector) > 0.3
                ORDER BY embedding <=> ${vectorString}::vector
                LIMIT ${limit};
            `;

            this.logger.log(`RAG found ${results.length} relevant documents (similarity > 0.3)`);
            return results;
        } catch (error) {
            this.logger.error('Search failed', error);
            return [];
        }
    }
}
