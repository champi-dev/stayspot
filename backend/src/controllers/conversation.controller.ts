import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { AuthRequest } from '../middleware/auth';
import { z } from 'zod';
import { chatCompletion, NO_THINK } from '../config/ai';

const prisma = new PrismaClient();

// Conversations with an auto-reply in flight — lets the client show a
// "host is typing…" indicator while the LLM generates the response.
const pendingReplies = new Map<string, number>();

const startConversationSchema = z.object({
  recipientId: z.string().uuid(),
  content: z.string().min(1),
});

const sendMessageSchema = z.object({
  content: z.string().min(1),
});

const CANNED_REPLIES = [
  "Thanks for reaching out! I'd be happy to help. The place is available for those dates.",
  "Great question! Yes, the amenities listed are all included. Let me know if you need anything else.",
  "Welcome! I'm glad you're interested. The neighborhood is really wonderful and safe.",
  "Thanks for your message! Check-in is flexible, just let me know your arrival time.",
  "Hi there! Feel free to ask any questions about the space. I want to make sure it's a great fit!",
  "That's a great idea! The area has lots of restaurants and cafes within walking distance.",
];

async function generateAIReply(conversationId: string, guestMessage: string, hostName: string): Promise<string> {
  // Get recent conversation history for context
  const recentMessages = await prisma.message.findMany({
    where: { conversationId },
    orderBy: { createdAt: 'desc' },
    take: 6,
    include: { sender: { select: { firstName: true } } },
  });

  const history = recentMessages.reverse().map(m =>
    `${m.sender.firstName}: ${m.content}`
  ).join('\n');

  try {
    const reply = await chatCompletion(
      [
        {
          role: 'system',
          content: `You are ${hostName}, a friendly and helpful vacation rental host. Reply to the guest's message naturally and helpfully. Keep responses short (1-3 sentences). Be warm, welcoming, and specific. Don't use emojis excessively.`,
        },
        {
          role: 'user',
          content: `Conversation so far:\n${history}\n\nReply as the host ${hostName}:${NO_THINK}`,
        },
      ],
      { temperature: 0.8, maxTokens: 200 },
    );
    return reply || CANNED_REPLIES[Math.floor(Math.random() * CANNED_REPLIES.length)];
  } catch {
    return CANNED_REPLIES[Math.floor(Math.random() * CANNED_REPLIES.length)];
  }
}

export async function getUserConversations(req: AuthRequest, res: Response): Promise<void> {
  const userId = req.userId!;

  const participations = await prisma.conversationParticipant.findMany({
    where: { userId },
    include: {
      conversation: {
        include: {
          messages: { orderBy: { createdAt: 'desc' }, take: 1 },
          participants: {
            include: {
              user: { select: { id: true, firstName: true, lastName: true, avatarUrl: true } },
            },
          },
        },
      },
    },
  });

  const conversations = participations
    .map(p => {
      const other = p.conversation.participants.find(pp => pp.userId !== userId);
      const lastMessage = p.conversation.messages[0];
      const unreadCount = 0; // Simplified for demo
      return {
        id: p.conversation.id,
        otherUser: other?.user || null,
        lastMessage: lastMessage ? {
          content: lastMessage.content,
          createdAt: lastMessage.createdAt,
          isRead: lastMessage.isRead,
          isOwn: lastMessage.senderId === userId,
        } : null,
        unreadCount,
        createdAt: p.conversation.createdAt,
      };
    })
    .sort((a, b) => {
      const aDate = a.lastMessage?.createdAt || a.createdAt;
      const bDate = b.lastMessage?.createdAt || b.createdAt;
      return new Date(bDate).getTime() - new Date(aDate).getTime();
    });

  res.json({ conversations });
}

export async function getMessages(req: AuthRequest, res: Response): Promise<void> {
  const conversationId = req.params.id as string;
  const page = parseInt(String(req.query.page || '1'), 10);
  const limit = parseInt(String(req.query.limit || '20'), 10);

  // Verify user is participant
  const participant = await prisma.conversationParticipant.findUnique({
    where: { conversationId_userId: { conversationId, userId: req.userId! } },
  });
  if (!participant) {
    res.status(404).json({ error: 'Not found', message: 'Conversation not found' });
    return;
  }

  // Mark messages as read
  await prisma.message.updateMany({
    where: { conversationId, senderId: { not: req.userId! }, isRead: false },
    data: { isRead: true },
  });

  const [messages, total] = await Promise.all([
    prisma.message.findMany({
      where: { conversationId },
      include: {
        sender: { select: { id: true, firstName: true, lastName: true, avatarUrl: true } },
      },
      orderBy: { createdAt: 'desc' },
      skip: (page - 1) * limit,
      take: limit,
    }),
    prisma.message.count({ where: { conversationId } }),
  ]);

  res.json({
    messages: messages.reverse(),
    hostTyping: pendingReplies.has(conversationId),
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  });
}

export async function sendMessage(req: AuthRequest, res: Response): Promise<void> {
  const conversationId = req.params.id as string;
  const parsed = sendMessageSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: 'Content is required' });
    return;
  }

  // Verify user is participant
  const participant = await prisma.conversationParticipant.findUnique({
    where: { conversationId_userId: { conversationId, userId: req.userId! } },
  });
  if (!participant) {
    res.status(404).json({ error: 'Not found', message: 'Conversation not found' });
    return;
  }

  const message = await prisma.message.create({
    data: {
      content: parsed.data.content,
      senderId: req.userId!,
      conversationId,
    },
    include: {
      sender: { select: { id: true, firstName: true, lastName: true, avatarUrl: true } },
    },
  });

  // Auto-reply after 3-5 seconds using OpenAI (async, don't await)
  const otherParticipant = await prisma.conversationParticipant.findFirst({
    where: { conversationId, userId: { not: req.userId! } },
    include: { user: { select: { firstName: true } } },
  });
  if (otherParticipant) {
    const delay = 1500 + Math.random() * 1500;
    const hostName = otherParticipant.user.firstName;
    pendingReplies.set(conversationId, Date.now());
    setTimeout(async () => {
      try {
        const reply = await generateAIReply(conversationId, parsed.data.content, hostName);
        await prisma.message.create({
          data: {
            content: reply,
            senderId: otherParticipant.userId,
            conversationId,
          },
        });
      } catch (err) {
        console.error('Auto-reply failed:', err);
      } finally {
        pendingReplies.delete(conversationId);
      }
    }, delay);
  }

  res.status(201).json({ message });
}

export async function startConversation(req: AuthRequest, res: Response): Promise<void> {
  const parsed = startConversationSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: parsed.error.errors[0].message });
    return;
  }

  const { recipientId, content } = parsed.data;
  const userId = req.userId!;

  // Check if conversation already exists
  const existing = await prisma.conversation.findFirst({
    where: {
      AND: [
        { participants: { some: { userId } } },
        { participants: { some: { userId: recipientId } } },
      ],
    },
  });

  if (existing) {
    // Send message to existing conversation
    const message = await prisma.message.create({
      data: { content, senderId: userId, conversationId: existing.id },
      include: {
        sender: { select: { id: true, firstName: true, lastName: true, avatarUrl: true } },
      },
    });
    res.json({ conversationId: existing.id, message });
    return;
  }

  // Create new conversation
  const conversation = await prisma.conversation.create({
    data: {
      participants: {
        create: [{ userId }, { userId: recipientId }],
      },
      messages: {
        create: { content, senderId: userId },
      },
    },
  });

  res.status(201).json({ conversationId: conversation.id });
}
