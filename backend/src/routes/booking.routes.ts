import { Router } from 'express';
import { createBooking, confirmBooking, getUserBookings, cancelBooking } from '../controllers/booking.controller';
import { authenticate } from '../middleware/auth';

export const bookingRouter = Router();

bookingRouter.post('/', authenticate, createBooking);
bookingRouter.post('/:id/confirm', authenticate, confirmBooking);
bookingRouter.get('/', authenticate, getUserBookings);
bookingRouter.delete('/:id', authenticate, cancelBooking);
