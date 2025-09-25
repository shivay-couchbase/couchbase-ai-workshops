import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import queryRoute from './routes/query.js';

dotenv.config();

const app = express();

const corsOptions = {
  origin: (origin, callback) => {
    if (!origin) {
      return callback(null, true);
    }
    if (origin.endsWith('.github.dev') || origin.startsWith('http://localhost:')) {
      return callback(null, true);
    }
    return callback(new Error('Not allowed by CORS'));
  },
  methods: ['GET', 'POST'], 
  allowedHeaders: ['Content-Type'],
};

app.use(cors(corsOptions));
app.use(express.json());

app.use('/api/query', queryRoute);

const port = process.env.PORT || 3001;
app.listen(port, () => {
  console.log(`Backend server is running on port ${port}`);
});
