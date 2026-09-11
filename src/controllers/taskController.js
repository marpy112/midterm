import mongoose from 'mongoose';
import { Task } from '../models/Task.js';

// Wraps an async handler so rejected promises reach the error middleware.
const asyncHandler = (fn) => (req, res, next) => fn(req, res, next).catch(next);

function assertValidId(id) {
  if (!mongoose.isValidObjectId(id)) {
    const err = new Error(`'${id}' is not a valid id`);
    err.status = 400;
    throw err;
  }
}

function notFound(id) {
  const err = new Error(`Task ${id} not found`);
  err.status = 404;
  return err;
}

// CREATE - POST /api/tasks
export const createTask = asyncHandler(async (req, res) => {
  const { title, description, status, dueDate } = req.body;
  const task = await Task.create({ title, description, status, dueDate });
  res.status(201).json({ data: task });
});

// READ (list) - GET /api/tasks?status=todo&search=foo&page=1&limit=20
export const listTasks = asyncHandler(async (req, res) => {
  const page = Math.max(parseInt(req.query.page, 10) || 1, 1);
  const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 20, 1), 100);

  const filter = {};
  if (req.query.status) filter.status = req.query.status;
  if (req.query.search) filter.title = { $regex: req.query.search, $options: 'i' };

  const [items, total] = await Promise.all([
    Task.find(filter).sort({ createdAt: -1 }).skip((page - 1) * limit).limit(limit),
    Task.countDocuments(filter),
  ]);

  res.json({
    data: items,
    meta: { total, page, limit, pages: Math.ceil(total / limit) || 1 },
  });
});

// READ (one) - GET /api/tasks/:id
export const getTask = asyncHandler(async (req, res, next) => {
  assertValidId(req.params.id);
  const task = await Task.findById(req.params.id);
  if (!task) return next(notFound(req.params.id));
  res.json({ data: task });
});

// UPDATE - PUT/PATCH /api/tasks/:id
export const updateTask = asyncHandler(async (req, res, next) => {
  assertValidId(req.params.id);
  const { title, description, status, dueDate } = req.body;
  const updates = { title, description, status, dueDate };
  Object.keys(updates).forEach((k) => updates[k] === undefined && delete updates[k]);

  const task = await Task.findByIdAndUpdate(req.params.id, updates, {
    new: true,
    runValidators: true,
  });
  if (!task) return next(notFound(req.params.id));
  res.json({ data: task });
});

// DELETE - DELETE /api/tasks/:id
export const deleteTask = asyncHandler(async (req, res, next) => {
  assertValidId(req.params.id);
  const task = await Task.findByIdAndDelete(req.params.id);
  if (!task) return next(notFound(req.params.id));
  res.status(204).send();
});
