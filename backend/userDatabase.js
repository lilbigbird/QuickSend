const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

// User database file
const userDatabaseFile = path.join(__dirname, 'userDatabase.json');

// Load user database from file
function loadUserDatabase() {
    try {
        if (fs.existsSync(userDatabaseFile)) {
            const data = fs.readFileSync(userDatabaseFile, 'utf8');
            return JSON.parse(data);
        }
    } catch (error) {
        console.error('Error loading user database:', error);
    }
    return {};
}

// Save user database to file
function saveUserDatabase(database) {
    try {
        fs.writeFileSync(userDatabaseFile, JSON.stringify(database, null, 2));
    } catch (error) {
        console.error('Error saving user database:', error);
    }
}

// Hash password
function hashPassword(password) {
    return crypto.createHash('sha256').update(password).digest('hex');
}

// Initialize user database
let userDatabase = loadUserDatabase();

// Create default admin user if database is empty
if (Object.keys(userDatabase).length === 0) {
    const defaultUser = {
        id: 'default-user',
        email: 'admin@quicksend.app',
        password: hashPassword('admin123'),
        name: 'Admin User',
        subscriptionTier: 'business',
        createdAt: new Date().toISOString(),
        lastLogin: null
    };
    userDatabase[defaultUser.email] = defaultUser;
    saveUserDatabase(userDatabase);
    console.log('Created default admin user: admin@quicksend.app / admin123');
}

// User authentication functions
function authenticateUser(email, password) {
    const user = userDatabase[email];
    if (!user) {
        return null;
    }
    
    const hashedPassword = hashPassword(password);
    if (user.password !== hashedPassword) {
        return null;
    }
    
    // Update last login
    user.lastLogin = new Date().toISOString();
    saveUserDatabase(userDatabase);
    
    // Return user without password
    const { password: _, ...userWithoutPassword } = user;
    return userWithoutPassword;
}

function createUser(email, password, name, phone = null) {
    // Check if user already exists
    if (userDatabase[email]) {
        return { success: false, error: 'User already exists' };
    }
    
    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(email)) {
        return { success: false, error: 'Invalid email format' };
    }
    
    // Validate password
    if (!password || password.length < 6) {
        return { success: false, error: 'Password must be at least 6 characters long' };
    }
    
    // Create new user
    const newUser = {
        id: crypto.randomUUID(),
        email: email.toLowerCase(),
        password: hashPassword(password),
        name: name || email.split('@')[0],
        phone: phone,
        subscriptionTier: 'free',
        createdAt: new Date().toISOString(),
        lastLogin: new Date().toISOString()
    };
    
    userDatabase[newUser.email] = newUser;
    saveUserDatabase(userDatabase);
    
    // Return user without password
    const { password: _, ...userWithoutPassword } = newUser;
    return { success: true, user: userWithoutPassword };
}

function updateUserEmail(currentEmail, newEmail) {
    const user = userDatabase[currentEmail];
    if (!user) {
        return { success: false, error: 'User not found' };
    }
    
    // Check if new email already exists
    if (userDatabase[newEmail] && newEmail !== currentEmail) {
        return { success: false, error: 'Email already in use' };
    }
    
    // Validate new email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(newEmail)) {
        return { success: false, error: 'Invalid email format' };
    }
    
    // Update user
    user.email = newEmail.toLowerCase();
    userDatabase[newEmail] = user;
    delete userDatabase[currentEmail];
    saveUserDatabase(userDatabase);
    
    // Return user without password
    const { password: _, ...userWithoutPassword } = user;
    return { success: true, user: userWithoutPassword };
}

function updateUserPassword(email, currentPassword, newPassword) {
    const user = userDatabase[email];
    if (!user) {
        return { success: false, error: 'User not found' };
    }
    
    // Verify current password
    const hashedCurrentPassword = hashPassword(currentPassword);
    if (user.password !== hashedCurrentPassword) {
        return { success: false, error: 'Current password is incorrect' };
    }
    
    // Validate new password
    if (!newPassword || newPassword.length < 6) {
        return { success: false, error: 'Password must be at least 6 characters long' };
    }
    
    // Update password
    user.password = hashPassword(newPassword);
    saveUserDatabase(userDatabase);
    
    return { success: true };
}

function getUserByEmail(email) {
    const user = userDatabase[email];
    if (!user) {
        return null;
    }
    
    // Return user without password
    const { password: _, ...userWithoutPassword } = user;
    return userWithoutPassword;
}

function updateUserProfile(email, updates) {
    const user = userDatabase[email];
    if (!user) {
        return { success: false, error: 'User not found' };
    }
    
    // Update allowed fields
    if (updates.name !== undefined) {
        user.name = updates.name;
    }
    if (updates.phone !== undefined) {
        user.phone = updates.phone;
    }
    if (updates.subscriptionTier !== undefined) {
        user.subscriptionTier = updates.subscriptionTier;
    }
    
    saveUserDatabase(userDatabase);
    
    // Return user without password
    const { password: _, ...userWithoutPassword } = user;
    return { success: true, user: userWithoutPassword };
}

function getAllUsers() {
    const users = [];
    for (const [email, user] of Object.entries(userDatabase)) {
        const { password: _, ...userWithoutPassword } = user;
        users.push(userWithoutPassword);
    }
    return users;
}

module.exports = {
    authenticateUser,
    createUser,
    updateUserEmail,
    updateUserPassword,
    getUserByEmail,
    updateUserProfile,
    getAllUsers,
    loadUserDatabase,
    saveUserDatabase
}; 