import { Router } from 'express';
import { searchListings, getListingById, getListingAvailability, getListingReviews } from '../controllers/listing.controller';

export const listingRouter = Router();

listingRouter.get('/', searchListings);
listingRouter.get('/:id', getListingById);
listingRouter.get('/:id/availability', getListingAvailability);
listingRouter.get('/:id/reviews', getListingReviews);
