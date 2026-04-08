import { Router } from 'express';
import {
  getUserConversations,
  getMessages,
  sendMessage,
  startConversation,
} from '../controllers/conversation.controller';
import { authenticate } from '../middleware/auth';

export const conversationRouter = Router();

conversationRouter.get('/', authenticate, getUserConversations);
conversationRouter.get('/:id/messages', authenticate, getMessages);
conversationRouter.post('/:id/messages', authenticate, sendMessage);
conversationRouter.post('/', authenticate, startConversation);
