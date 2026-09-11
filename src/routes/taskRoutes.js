import { Router } from 'express';
import {
  createTask,
  listTasks,
  getTask,
  updateTask,
  deleteTask,
} from '../controllers/taskController.js';

const router = Router();

router.route('/').get(listTasks).post(createTask);
router.route('/:id').get(getTask).put(updateTask).patch(updateTask).delete(deleteTask);

export default router;
