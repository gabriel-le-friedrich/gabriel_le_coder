// Index.js
import express from 'express';
import jwt from 'jsonwebtoken';
import { authenticateToken } from './auth.middleware.js';

const app = express();

app.use(express.json());

// Generate a secret key for signing JWTs (normally this would be a long and random string)
const secret = 'very_Secure_secret_key';
const refresh_token_1 = "enter user1 refresh token here";

// In a real application, this data would be stored in a database
const users = [
  { id: 1, username: 'user1', password: 'password1' },
  { id: 2, username: 'user2', password: 'password2' },
];

// Index route
app.get('/', (_req, res) => {
    return res.status(200).send({ message: "access_token_refresh_token"});
});

// Route for logging in and generating tokens
app.post('/login', (req, res) => {
  // In a real application, this would be validated against a database
  const user = users.find(u => u.username === req.body.username && u.password === req.body.password);

  if (user) {
    // Generate an access token with a short expiry time (e.g. 10 minutes)
    const accessToken = jwt.sign({ userId: user.id }, secret, { expiresIn: '1m' });

    // Generate a refresh token with a long expiry time (e.g. 30 days)
    const refreshToken = jwt.sign({ userId: user.id }, secret, { expiresIn: '30d' });

    res.json({ accessToken, refreshToken });
  } else {
    res.status(401).json({ error: 'Invalid username or password' });
  }
});

// In a real application, this would retrieve data from a database based on the user id
app.get('/protected', authenticateToken, (_req, res) => {
    return res.status(200).send({ message: "This is the protected message "});
})

app.listen(3000, () => {
  console.log('Server listening on port 3000');
});

// Route for refreshing tokens
app.post('/refresh', (req, res) => {
  const refreshToken = req.body.refreshToken;

  // Verify that the refresh token is valid and retrieve the user ID from it
  jwt.verify(refreshToken, secret, (err, decoded) => {
    if (err) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }
    const userId = decoded.id;
    // Check if the refresh token is in the database and has not expired
    // This would typically be done using a database query
    const refreshTokens = [
      { userId: 1, refreshToken: 'refresh_token_1', expiry: Date.now() + 30 * 24 * 60 * 60 * 1000 },
      { userId: 2, refreshToken: 'refresh_token_2', expiry: Date.now() + 30 * 24 * 60 * 60 * 1000 },
    ];

    const storedToken = refreshTokens.find((token) => token.refreshToken === refreshToken);

    if (!storedToken || storedToken.userId !== userId || storedToken.expiry < Date.now()) {
      return res.status(401).json({ error: 'Invalid refresh token' });
    }

    // Generate a new access token with a short expiry time (e.g. 10 minutes)
    const accessToken = jwt.sign({ userId }, secret, { expiresIn: '10m' });

    // Generate a new refresh token with a long expiry time (e.g. 30 days)
    const newRefreshToken = jwt.sign({ userId }, secret, { expiresIn: '30d' });

    // Update the refresh token in the database with the new value and expiry time
    storedToken.refreshToken = newRefreshToken;
    storedToken.expiry = Date.now() + 30 * 24 * 60 * 60 * 1000;

    // Return the new access token and refresh token to the client
    res.json({ accessToken, refreshToken: newRefreshToken });
  });
});