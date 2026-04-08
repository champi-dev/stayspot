import { z } from 'zod';

export const createBookingSchema = z.object({
  listingId: z.string().uuid(),
  checkIn: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)),
  checkOut: z.string().datetime({ offset: true }).or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/)),
  guests: z.number().int().min(1).max(20),
});

export type CreateBookingInput = z.infer<typeof createBookingSchema>;
