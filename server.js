const express = require('express');
const path = require('path');
const fs = require('fs');
const app = express();
const feedbackFile = path.join(__dirname, 'data', 'feedback.json');
const adminToken = process.env.ADMIN_TOKEN || 'unseenhg2056';

if (!fs.existsSync(path.dirname(feedbackFile))) {
    fs.mkdirSync(path.dirname(feedbackFile), { recursive: true });
}

if (!fs.existsSync(feedbackFile)) {
    fs.writeFileSync(feedbackFile, '[]');
}

app.use(express.json());
app.use(express.static(path.join(__dirname, 'public')));
app.use('/jpg', express.static(path.join(__dirname, 'jpg')));
app.use('/api', (req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, X-Admin-Token');

    if (req.method === 'OPTIONS') {
        return res.sendStatus(204);
    }

    next();
});

app.get('/api/feedback', (_req, res) => {
    const token = _req.headers['x-admin-token'];
    if (token !== adminToken) {
        return res.status(401).json({ error: 'Unauthorized.' });
    }

    try {
        const raw = fs.readFileSync(feedbackFile, 'utf8');
        res.json(JSON.parse(raw));
    } catch (_error) {
        res.status(500).json({ error: 'Failed to load feedback.' });
    }
});

app.post('/api/feedback', (req, res) => {
    const { name, phone, rating, message } = req.body ?? {};

    if (!name || !message || !rating) {
        return res.status(400).json({ error: 'Name, rating, and message are required.' });
    }

    try {
        const raw = fs.readFileSync(feedbackFile, 'utf8');
        const feedback = JSON.parse(raw);
        const entry = {
            id: Date.now(),
            name,
            phone: phone || '',
            rating,
            message,
            createdAt: new Date().toISOString(),
        };

        feedback.unshift(entry);
        fs.writeFileSync(feedbackFile, JSON.stringify(feedback, null, 2));
        res.status(201).json({ ok: true, entry });
    } catch (_error) {
        res.status(500).json({ error: 'Failed to save feedback.' });
    }
});

app.get('/admin', (_req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'admin.html'));
});

app.get('/', (_req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

const port = process.env.PORT || 3000;

app.listen(port, () => {
    console.log(`Unseen Hunger server running on http://localhost:${port}`);
});
