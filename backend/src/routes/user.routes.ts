import { Router } from 'express';
import { updateProfile, getPublicProfile } from '../controllers/user.controller';
import { authenticate } from '../middleware/auth';

export const userRouter = Router();

userRouter.put('/me', authenticate, updateProfile);
userRouter.get('/:id/public', getPublicProfile);
