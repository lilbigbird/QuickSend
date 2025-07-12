const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
require('dotenv').config();

// Database connection
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-in-production';
const JWT_EXPIRES_IN = '7d'; // 7 days

// Initialize users table
async function initializeUsersTable() {
    try {
        const createTableQuery = `
            CREATE TABLE IF NOT EXISTS users (
                id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
                email VARCHAR(255) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                name VARCHAR(255) NOT NULL,
                phone VARCHAR(20),
                subscription_tier VARCHAR(20) DEFAULT 'free',
                created_at TIMESTAMPTZ DEFAULT NOW(),
                last_login TIMESTAMPTZ DEFAULT NOW(),
                is_active BOOLEAN DEFAULT TRUE,
                profile_picture_url TEXT,
                next_billing_date TIMESTAMPTZ
            );
        `;
        await pool.query(createTableQuery);
        console.log('Users table initialized successfully');
    } catch (error) {
        console.error('Error initializing users table:', error);
    }
}

// User registration
async function registerUser(email, password, name, phone = null) {
    try {
        // Check if user already exists
        const existingUser = await pool.query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existingUser.rows.length > 0) {
            throw new Error('User already exists');
        }

        // Hash password
        const saltRounds = 12;
        const passwordHash = await bcrypt.hash(password, saltRounds);

        // Insert new user
        const result = await pool.query(
            `INSERT INTO users (email, password_hash, name, phone, subscription_tier)
             VALUES ($1, $2, $3, $4, $5)
             RETURNING id, email, name, phone, subscription_tier, created_at, last_login`,
            [email, passwordHash, name, phone, 'free']
        );

        const user = result.rows[0];
        
        // Generate JWT token
        const token = jwt.sign(
            { userId: user.id, email: user.email },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );

        return {
            success: true,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                phone: user.phone,
                subscriptionTier: user.subscription_tier,
                createdAt: user.created_at,
                lastSignIn: user.last_login
            },
            token
        };
    } catch (error) {
        console.error('Registration error:', error);
        throw error;
    }
}

// User login
async function loginUser(email, password) {
    try {
        // Find user by email
        const result = await pool.query(
            'SELECT * FROM users WHERE email = $1 AND is_active = TRUE',
            [email]
        );

        if (result.rows.length === 0) {
            throw new Error('Invalid email or password');
        }

        const user = result.rows[0];

        // Verify password
        const isPasswordValid = await bcrypt.compare(password, user.password_hash);
        if (!isPasswordValid) {
            throw new Error('Invalid email or password');
        }

        // Update last login
        await pool.query(
            'UPDATE users SET last_login = NOW() WHERE id = $1',
            [user.id]
        );

        // Generate JWT token
        const token = jwt.sign(
            { userId: user.id, email: user.email },
            JWT_SECRET,
            { expiresIn: JWT_EXPIRES_IN }
        );

        return {
            success: true,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                phone: user.phone,
                subscriptionTier: user.subscription_tier,
                createdAt: user.created_at,
                lastSignIn: new Date()
            },
            token
        };
    } catch (error) {
        console.error('Login error:', error);
        throw error;
    }
}

// Verify JWT token middleware
function authenticateToken(req, res, next) {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1]; // Bearer TOKEN

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    jwt.verify(token, JWT_SECRET, async (err, decoded) => {
        if (err) {
            return res.status(403).json({ error: 'Invalid or expired token' });
        }

        try {
            // Get user from database
            const result = await pool.query(
                'SELECT id, email, name, subscription_tier, created_at, last_login FROM users WHERE id = $1 AND is_active = TRUE',
                [decoded.userId]
            );

            if (result.rows.length === 0) {
                return res.status(403).json({ error: 'User not found' });
            }

            req.user = result.rows[0];
            next();
        } catch (error) {
            console.error('Token verification error:', error);
            return res.status(500).json({ error: 'Internal server error' });
        }
    });
}

// Update user subscription
async function updateSubscription(userId, subscriptionTier) {
    try {
        let nextBillingDate = null;
        if (subscriptionTier !== 'free') {
            nextBillingDate = new Date();
            nextBillingDate.setMonth(nextBillingDate.getMonth() + 1);
        }

        const result = await pool.query(
            `UPDATE users 
             SET subscription_tier = $1, next_billing_date = $2
             WHERE id = $3
             RETURNING id, email, name, subscription_tier, created_at, last_login`,
            [subscriptionTier, nextBillingDate, userId]
        );

        if (result.rows.length === 0) {
            throw new Error('User not found');
        }

        return result.rows[0];
    } catch (error) {
        console.error('Subscription update error:', error);
        throw error;
    }
}

// Get user by ID
async function getUserById(userId) {
    try {
        const result = await pool.query(
            'SELECT id, email, name, phone, subscription_tier, created_at, last_login FROM users WHERE id = $1 AND is_active = TRUE',
            [userId]
        );

        if (result.rows.length === 0) {
            return null;
        }

        return result.rows[0];
    } catch (error) {
        console.error('Get user error:', error);
        throw error;
    }
}

module.exports = {
    initializeUsersTable,
    registerUser,
    loginUser,
    authenticateToken,
    updateSubscription,
    getUserById
}; 