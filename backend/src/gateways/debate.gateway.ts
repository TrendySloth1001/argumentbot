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
import { UseGuards, Logger } from '@nestjs/common';
import { DebateService } from '../debate/debate.service';
// import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard'; // Socket auth is tricky, skip for now or use middleware

@WebSocketGateway({
    cors: {
        origin: '*',
    },
    namespace: 'debate',
})
export class DebateGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    private logger = new Logger('DebateGateway');

    constructor(private readonly debateService: DebateService) { }

    handleConnection(client: Socket) {
        this.logger.log(`Client connected: ${client.id}`);
    }

    handleDisconnect(client: Socket) {
        this.logger.log(`Client disconnected: ${client.id}`);
    }

    @SubscribeMessage('join_room')
    handleJoinRoom(
        @MessageBody() data: { debateId: string; userId: string },
        @ConnectedSocket() client: Socket,
    ) {
        this.logger.log(`Client ${client.id} joining room ${data.debateId}`);
        client.join(data.debateId);
        client.emit('joined_room', { debateId: data.debateId });
        this.server.to(data.debateId).emit('user_joined', { userId: data.userId });
    }

    @SubscribeMessage('leave_room')
    handleLeaveRoom(
        @MessageBody() data: { debateId: string },
        @ConnectedSocket() client: Socket,
    ) {
        client.leave(data.debateId);
        this.logger.log(`Client ${client.id} left room ${data.debateId}`);
    }

    @SubscribeMessage('submit_turn')
    async handleSubmitTurn(
        @MessageBody()
        data: {
            debateId: string;
            userId: string;
            content: string;
            speaker: 'USER' | 'MODEL_A' | 'MODEL_B';
        },
        @ConnectedSocket() client: Socket,
    ) {
        this.logger.log(`Turn submitted for ${data.debateId} by ${data.userId}`);

        // Broadcast turn immediately to everyone (including sender for confirmation)
        this.server.to(data.debateId).emit('new_turn', {
            speaker: data.speaker,
            content: data.content,
            userId: data.userId,
            timestamp: new Date().toISOString(),
        });

        try {
            // Process turn and get AI analysis
            const result = await this.debateService.processMultiplayerTurn(
                data.debateId,
                data.userId,
                data.content
            );

            // Broadcast score/analysis
            this.server.to(data.debateId).emit('score_update', {
                turnId: result.turn.id,
                analysis: result.analysis,
                finished: result.finished,
                userId: data.userId
            });

            if (result.finished) {
                this.server.to(data.debateId).emit('debate_finished', {
                    reason: 'Concession',
                    lastSpeaker: data.userId
                });
            }
        } catch (e) {
            this.logger.error(`Error processing turn: ${e.message}`, e.stack);
            client.emit('error', { message: 'Failed to process turn' });
        }
    }

    @SubscribeMessage('typing_started')
    handleTypingStarted(
        @MessageBody() data: { debateId: string; userId: string },
        @ConnectedSocket() client: Socket,
    ) {
        client.to(data.debateId).emit('opponent_typing', { userId: data.userId });
    }

    @SubscribeMessage('typing_stopped')
    handleTypingStopped(
        @MessageBody() data: { debateId: string; userId: string },
        @ConnectedSocket() client: Socket,
    ) {
        client.to(data.debateId).emit('opponent_stopped_typing', { userId: data.userId });
    }
}
