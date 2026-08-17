// Prefer an explicit VITE_API_URL. If not provided, fall back to the current
// page origin (so the frontend will call the backend on the same host/origin).
// This makes it safe to open the frontend by IP or behind a reverse-proxy
// without the UI trying to call localhost:3001.
const defaultOrigin = typeof window !== 'undefined' ? window.location.origin : 'http://localhost:3001';
export const API_URL = import.meta.env.VITE_API_URL || defaultOrigin;
