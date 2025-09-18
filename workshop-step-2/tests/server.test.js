const request = require('supertest');
const { app, server } = require('../server'); // Import both app and server
const { generateQueryEmbedding, storeEmbedding } = require('../helpers');
const fs = require('fs');

// Mock the helper functions
jest.mock('../helpers', () => ({
  generateQueryEmbedding: jest.fn(),
  storeEmbedding: jest.fn(),
}));

// Mock the 'couchbase' module
jest.mock('couchbase', () => ({
  connect: jest.fn(),
  SearchRequest: {
    create: jest.fn(),
  },
  VectorSearch: {
    fromVectorQuery: jest.fn(),
  },
  VectorQuery: {
    create: jest.fn(() => ({
      numCandidates: jest.fn().mockReturnThis(),
    })),
  },
}));

// Mock console.log and console.error to suppress test log output
beforeAll(() => {
  jest.spyOn(global.console, 'log').mockImplementation(() => {});
  jest.spyOn(global.console, 'error').mockImplementation(() => {});
});

// Restore mocks after the tests
afterAll(() => {
  jest.restoreAllMocks();
  server.close();
});