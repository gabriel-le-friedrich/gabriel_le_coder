// auth.middleware.js
import jwt from 'jsonwebtoken';
const secret = 'very_Secure_secret_key';

export function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) {
    return res.status(401).json({ error: 'Access token not provided' });
  }
  jwt.verify(token, secret, (err, payload) => {
    if (err) {
      return res.status(403).json({ error: 'Invalid or expired access token' });
    }
    // Attach the user ID to the request object for use in subsequent handlers
    req.id = payload.id;
    next();
  });
}