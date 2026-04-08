import { Router } from 'express';
import { authRouter } from './auth.routes';
import { locationRouter } from './location.routes';
import { listingRouter } from './listing.routes';
import { bookingRouter } from './booking.routes';
import { wishlistRouter } from './wishlist.routes';
import { conversationRouter } from './conversation.routes';
import { userRouter } from './user.routes';

export const router = Router();

router.get('/', (_req, res) => {
  res.json({ message: 'StaySpot API v1' });
});

router.use('/auth', authRouter);
router.use('/locations', locationRouter);
router.use('/listings', listingRouter);
router.use('/bookings', bookingRouter);
router.use('/wishlists', wishlistRouter);
router.use('/conversations', conversationRouter);
router.use('/users', userRouter);
