import { Response } from 'express';
import { PrismaClient } from '@prisma/client';
import { createBookingSchema } from '../validators/booking';
import { AuthRequest } from '../middleware/auth';

const prisma = new PrismaClient();

export async function createBooking(req: AuthRequest, res: Response): Promise<void> {
  const parsed = createBookingSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: 'Validation error', message: parsed.error.errors[0].message });
    return;
  }

  const { listingId, checkIn, checkOut, guests } = parsed.data;
  const userId = req.userId!;

  // Get listing
  const listing = await prisma.listing.findUnique({ where: { id: listingId } });
  if (!listing) {
    res.status(404).json({ error: 'Not found', message: 'Listing not found' });
    return;
  }

  const checkInDate = new Date(checkIn);
  const checkOutDate = new Date(checkOut);

  if (checkOutDate <= checkInDate) {
    res.status(400).json({ error: 'Validation error', message: 'Check-out must be after check-in' });
    return;
  }

  // Check availability (date conflicts)
  const conflict = await prisma.booking.findFirst({
    where: {
      listingId,
      status: { in: ['CONFIRMED', 'PENDING'] },
      OR: [
        { checkIn: { lt: checkOutDate }, checkOut: { gt: checkInDate } },
      ],
    },
  });

  if (conflict) {
    res.status(409).json({ error: 'Conflict', message: 'These dates are no longer available' });
    return;
  }

  // Calculate total
  const nights = Math.ceil((checkOutDate.getTime() - checkInDate.getTime()) / (1000 * 60 * 60 * 24));
  const totalPrice = (listing.pricePerNight * nights) + listing.cleaningFee + listing.serviceFee;

  const booking = await prisma.booking.create({
    data: {
      checkIn: checkInDate,
      checkOut: checkOutDate,
      guests,
      totalPrice,
      guestId: userId,
      listingId,
    },
    include: {
      listing: {
        include: {
          images: { take: 1, orderBy: { sortOrder: 'asc' } },
          location: { select: { name: true } },
        },
      },
    },
  });

  res.status(201).json({ booking });
}

export async function confirmBooking(req: AuthRequest, res: Response): Promise<void> {
  const bookingId = req.params.id as string;

  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking || booking.guestId !== req.userId) {
    res.status(404).json({ error: 'Not found', message: 'Booking not found' });
    return;
  }

  if (booking.status !== 'PENDING') {
    res.status(400).json({ error: 'Bad request', message: 'Booking is not pending' });
    return;
  }

  // Simulate 2s payment processing
  await new Promise(resolve => setTimeout(resolve, 2000));

  const updated = await prisma.booking.update({
    where: { id: bookingId },
    data: { status: 'CONFIRMED' },
    include: {
      listing: {
        include: {
          images: { take: 1, orderBy: { sortOrder: 'asc' } },
          location: { select: { name: true } },
          host: { select: { id: true, firstName: true } },
        },
      },
    },
  });

  // Auto-create welcome conversation from host (fire and forget)
  if (updated.listing) {
    const hostId = updated.listing.hostId;
    const guestId = req.userId!;
    const listingTitle = updated.listing.title;
    const hostName = (updated.listing as any).host?.firstName || 'Your host';

    createWelcomeConversation(hostId, guestId, listingTitle, hostName)
      .catch(err => console.error('Welcome message failed:', err));
  }

  res.json({ booking: updated });
}

async function createWelcomeConversation(hostId: string, guestId: string, listingTitle: string, hostName: string) {
  // If host and guest are the same (demo mode), skip
  if (hostId === guestId) {
    // Create a "virtual host" conversation — use the system to send a message
    // Find or create a conversation with just the user, simulating a host message
    const conversation = await prisma.conversation.create({
      data: {
        participants: { create: [{ userId: guestId }] },
        messages: {
          create: {
            content: `Hi! Thanks for booking "${listingTitle}"! I'm ${hostName}, your host. Let me know if you have any questions about the place or the area. Looking forward to hosting you!`,
            senderId: guestId,
          },
        },
      },
    });
    return;
  }

  // Check if conversation already exists
  const existing = await prisma.conversation.findFirst({
    where: {
      AND: [
        { participants: { some: { userId: hostId } } },
        { participants: { some: { userId: guestId } } },
      ],
    },
  });

  const message = `Hi! Thanks for booking "${listingTitle}"! I'm ${hostName}, your host. Let me know if you have any questions about the place or the area. Looking forward to hosting you!`;

  if (existing) {
    await prisma.message.create({
      data: { content: message, senderId: hostId, conversationId: existing.id },
    });
  } else {
    await prisma.conversation.create({
      data: {
        participants: { create: [{ userId: hostId }, { userId: guestId }] },
        messages: { create: { content: message, senderId: hostId } },
      },
    });
  }
}

export async function getUserBookings(req: AuthRequest, res: Response): Promise<void> {
  const userId = req.userId!;

  const bookings = await prisma.booking.findMany({
    where: { guestId: userId },
    include: {
      listing: {
        include: {
          images: { take: 1, orderBy: { sortOrder: 'asc' } },
          location: { select: { name: true } },
        },
      },
    },
    orderBy: { createdAt: 'desc' },
  });

  const now = new Date();
  const upcoming = bookings.filter(b =>
    new Date(b.checkIn) >= now && b.status !== 'CANCELLED'
  );
  const past = bookings.filter(b =>
    new Date(b.checkIn) < now || b.status === 'CANCELLED'
  );

  res.json({ upcoming, past });
}

export async function cancelBooking(req: AuthRequest, res: Response): Promise<void> {
  const bookingId = req.params.id as string;

  const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
  if (!booking || booking.guestId !== req.userId) {
    res.status(404).json({ error: 'Not found', message: 'Booking not found' });
    return;
  }

  if (booking.status === 'CANCELLED') {
    res.status(400).json({ error: 'Bad request', message: 'Booking is already cancelled' });
    return;
  }

  const updated = await prisma.booking.update({
    where: { id: bookingId },
    data: { status: 'CANCELLED' },
  });

  res.json({ booking: updated });
}
