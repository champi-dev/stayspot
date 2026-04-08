import { Router } from 'express';
import {
  getUserWishlists,
  createWishlist,
  addListingToWishlist,
  removeListingFromWishlist,
} from '../controllers/wishlist.controller';
import { authenticate } from '../middleware/auth';

export const wishlistRouter = Router();

wishlistRouter.get('/', authenticate, getUserWishlists);
wishlistRouter.post('/', authenticate, createWishlist);
wishlistRouter.post('/:id/listings', authenticate, addListingToWishlist);
wishlistRouter.delete('/:id/listings/:listingId', authenticate, removeListingFromWishlist);
