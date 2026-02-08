
import {
    OnGatewayConnection,
    OnGatewayDisconnect,
    WebSocketGateway,
    WebSocketServer,
    SubscribeMessage,
    MessageBody,
    ConnectedSocket,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import WebSocket from 'ws';

@WebSocketGateway({ namespace: 'stt', cors: { origin: '*' } })
export class SttGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    // Map client Socket.ID -> Python Service WebSocket
    private serviceConnections = new Map<string, WebSocket>();

    handleConnection(client: Socket) {
        console.log(`STT Client connected: ${client.id}`);

        // Connect to Python STT Service
        // Default to 127.0.0.1:8000 since backend often runs on host and localhost might resolve to IPv6
        const sttServiceUrl = process.env.STT_SERVICE_URL || 'ws://127.0.0.1:8000/listen';

        // Fallback for local testing if not in docker
        // const url = 'ws://localhost:8000/listen'; 

        try {
            const serviceWs = new WebSocket(sttServiceUrl);

            serviceWs.on('open', () => {
                console.log(`Connected to STT Service for client ${client.id}`);
                this.serviceConnections.set(client.id, serviceWs);
            });

            serviceWs.on('message', (data) => {
                // Received transcription from Python Service
                // Forward to Client
                try {
                    const message = data.toString();
                    // console.log(`STT Transcription: ${message}`);
                    client.emit('transcription', message);
                } catch (e) {
                    console.error('Error parsing/forwarding STT message', e);
                }
            });

            serviceWs.on('error', (error) => {
                console.error(`STT Service connection error for ${client.id}:`, error);
                client.emit('error', { message: 'STT Service connection failed' });
            });

            serviceWs.on('close', () => {
                console.log(`STT Service connection closed for ${client.id}`);
                this.serviceConnections.delete(client.id);
            });

        } catch (e) {
            console.error(`Failed to connect to STT Service`, e);
            client.disconnect();
        }
    }

    handleDisconnect(client: Socket) {
        console.log(`STT Client disconnected: ${client.id}`);
        const serviceWs = this.serviceConnections.get(client.id);
        if (serviceWs) {
            serviceWs.close();
            this.serviceConnections.delete(client.id);
        }
    }

    @SubscribeMessage('audio_chunk')
    handleAudioChunk(
        @MessageBody() data: any,
        @ConnectedSocket() client: Socket,
    ) {
        const serviceWs = this.serviceConnections.get(client.id);
        if (serviceWs && serviceWs.readyState === WebSocket.OPEN) {
            // console.log(`Received audio chunk type: ${typeof data}, isBuffer: ${Buffer.isBuffer(data)}, length: ${data?.length}`);
            if (Buffer.isBuffer(data)) {
                serviceWs.send(data);
            } else {
                // If it's an ArrayBuffer (likely from socket.io), convert to Buffer
                serviceWs.send(Buffer.from(data));
            }
        }
    }
}
