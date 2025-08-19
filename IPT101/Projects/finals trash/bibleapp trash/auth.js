// Handle login form submission
function handleLogin(e) {
    e.preventDefault();
    
    // Get form values
    const email = document.getElementById("login-email").value;
    const password = document.getElementById("login-password").value;
    
    // Validate inputs
    if (!email || !password) {
        showError(loginError, "Please enter both email and password");
        return;
    }
    
    // Show loader
    loginForm.style.display = "none";
    loader.style.display = "block";
    
    // For a frontend-only app, check if the user exists in localStorage
    const users = JSON.parse(localStorage.getItem("bibleAppUsers") || "[]");
    const user = users.find(u => u.email === email && u.password === password);
    
    setTimeout(() => {
        if (user) {
            // Create a user object without the password for state
            const safeUser = {
                name: user.name,
                email: user.email
            };
            
            // Set user in state
            state.user = safeUser;
            
            // Store in localStorage as current user
            localStorage.setItem("bibleAppUser", JSON.stringify(safeUser));
            
            // Close modal and update UI
            closeModal(loginModal);
            updateAuthUI();
            
            console.log("Login successful for:", email);
        } else {
            showError(loginError, "Invalid email or password");
        }
        
        // Hide loader and show form
        loginForm.style.display = "block";
        loader.style.display = "none";
    }, 1000); // Simulate network delay
}

// Handle signup form submission
function handleSignup(e) {
    e.preventDefault();
    const name = document.getElementById("signup-name").value;
    const email = document.getElementById("signup-email").value;
    const password = document.getElementById("signup-password").value;
    const confirmPassword = document.getElementById("signup-confirm").value;

    // Validate fields
    if (!name || !email || !password || !confirmPassword) {
        showError(signupError, "Please fill in all fields");
        return;
    }

    if (password !== confirmPassword) {
        showError(signupError, "Passwords do not match");
        return;
    }

    // Simple email validation
    if (!email.includes('@') || !email.includes('.')) {
        showError(signupError, "Please enter a valid email address");
        return;
    }

    // Show loader
    signupForm.style.display = "none";
    loader.style.display = "block";
    
    // For a frontend-only app, store users in localStorage
    let users = JSON.parse(localStorage.getItem("bibleAppUsers") || "[]");
    
    // Check if user already exists
    const existingUser = users.find(u => u.email === email);
    
    setTimeout(() => {
        if (existingUser) {
            showError(signupError, "An account with this email already exists");
            signupForm.style.display = "block";
            loader.style.display = "none";
            return;
        }
        
        // Add new user
        const newUser = {
            name: name,
            email: email,
            password: password // In a real app, this would be hashed
        };
        
        users.push(newUser);
        localStorage.setItem("bibleAppUsers", JSON.stringify(users));
        
        // Create a user object without the password for state
        const safeUser = {
            name: newUser.name,
            email: newUser.email
        };
        
        // Set user in state and localStorage
        state.user = safeUser;
        localStorage.setItem("bibleAppUser", JSON.stringify(safeUser));
        
        // Close modal and update UI
        closeModal(signupModal);
        updateAuthUI();
        
        // Create initial empty user data structures
        initializeUserData(email);
        
        console.log("Signup successful for:", email);
        
        // Hide loader
        signupForm.style.display = "block";
        loader.style.display = "none";
    }, 1000); // Simulate network delay
}

function handleLogout() {
    console.log("Logging out user");
    
    // Clear user data from state
    state.user = null;

    // Remove current user from localStorage
    localStorage.removeItem("bibleAppUser");

    // Clear user-specific data
    state.bookmarks = [];
    state.highlights = [];
    state.notes = [];

    // Update UI to reflect logged out state
    updateAuthUI();
}

// Initialize data structures for a new user
function initializeUserData(email) {
    // Create empty arrays for user data
    const userData = {
        bookmarks: [],
        highlights: [],
        notes: []
    };
    
    // Store user-specific data
    localStorage.setItem(`bibleAppData_${email}`, JSON.stringify(userData));
}

// Load user-specific data
function loadUserData() {
    if (!state.user || !state.user.email) return;
    
    const userData = localStorage.getItem(`bibleAppData_${state.user.email}`);
    if (userData) {
        try {
            const data = JSON.parse(userData);
            state.bookmarks = data.bookmarks || [];
            state.highlights = data.highlights || [];
            state.notes = data.notes || [];
        } catch (e) {
            console.error("Error loading user data:", e);
        }
    } else {
        // Initialize data for this user if it doesn't exist
        initializeUserData(state.user.email);
    }
}