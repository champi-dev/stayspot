import { Router } from 'express';
import { searchAutocomplete, getOrGenerateLocation } from '../controllers/location.controller';

export const locationRouter = Router();

locationRouter.get('/autocomplete', searchAutocomplete);
locationRouter.get('/:placeId', getOrGenerateLocation);
