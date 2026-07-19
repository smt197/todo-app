const express = require('express');
const cors = require('cors');
require('dotenv').config();
const { createTable } = require('./config/database');
const todoRoutes = require('./routes/todoRoutes');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/todos', todoRoutes);

// Route de test
app.get('/health', (req, res) => {
  res.json({ status: 'OK' });
});

// Démarrer le serveur
const startServer = async () => {
  try {
    await createTable();
    app.listen(PORT, () => {
      console.log(`🚀 Serveur démarré sur http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error('Erreur au démarrage:', err);
  }
};

startServer();