import {
    WebSocketGateway,
    WebSocketServer,
    SubscribeMessage,
    OnGatewayConnection,
    OnGatewayDisconnect,
    MessageBody,
    ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger } from '@nestjs/common';
import { DebateService } from '../debate/debate.service';
import { DebateMode, DebateRole } from '@prisma/client';

@WebSocketGateway({
    cors: {
        origin: '*',
    },
    namespace: 'matchmaking',
})
export class MatchmakingGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    private logger = new Logger('MatchmakingGateway');
    private queue: { socketId: string; userId: string; username: string }[] = [];

    constructor(private readonly debateService: DebateService) { }

    handleConnection(client: Socket) {
        this.logger.log(`Matchmaking Client connected: ${client.id}`);
    }

    handleDisconnect(client: Socket) {
        this.logger.log(`Matchmaking Client disconnected: ${client.id}`);
        this.removeFromQueue(client.id);
    }

    @SubscribeMessage('join_queue')
    async handleJoinQueue(
        @MessageBody() data: { userId: string; username: string },
        @ConnectedSocket() client: Socket,
    ) {
        // Check if user is already in queue
        if (this.queue.find((p) => p.userId === data.userId)) {
            this.logger.log(`User ${data.username} already in queue`);
            return;
        }

        this.logger.log(`User ${data.username} joined matchmaking queue`);
        this.queue.push({ socketId: client.id, userId: data.userId, username: data.username });
        client.emit('queue_joined', { position: this.queue.length });

        this.tryMatch();
    }

    @SubscribeMessage('leave_queue')
    handleLeaveQueue(@ConnectedSocket() client: Socket) {
        this.removeFromQueue(client.id);
        client.emit('queue_left');
    }

    private removeFromQueue(socketId: string) {
        this.queue = this.queue.filter((p) => p.socketId !== socketId);
    }

    private async tryMatch() {
        if (this.queue.length >= 2) {
            const player1 = this.queue.shift();
            const player2 = this.queue.shift();

            if (player1 && player2) {
                this.logger.log(`Match found: ${player1.username} vs ${player2.username}`);

                // Create a debate
                const topic = await this.getRandomTopic();
                // player1 = Pro (Model A logic), player2 = Con (Model B logic / Opponent)
                // But for Human vs Human, we use USER role? 
                // Actually, we need to adapt DebateService to support storing 2 user IDs.
                // We added opponentId to schema.

                // We need a method in DebateService to create this specific type of debate.
                const debate = await this.debateService.createMultiplayerDebate(
                    topic,
                    player1.userId,
                    player2.userId
                );

                // Notify players
                this.server.to(player1.socketId).emit('match_found', {
                    debateId: debate.id,
                    role: 'PRO',
                    opponent: player2.username,
                    topic: topic
                });

                this.server.to(player2.socketId).emit('match_found', {
                    debateId: debate.id,
                    role: 'CON',
                    opponent: player1.username,
                    topic: topic
                });
            }
        }
    }

    private async getRandomTopic(): Promise<string> {
        // Mock for now, or fetch from DB/LlmService
        const topics = [
            "Artificial Intelligence will replace human creativity.",
            "Social media does more harm than good.",
            "Universal Basic Income is necessary for the future.",
            "Space exploration is a waste of resources.",
            "Remote work is better than office work."
        ];
        return topics[Math.floor(Math.random() * topics.length)];
    }
}
