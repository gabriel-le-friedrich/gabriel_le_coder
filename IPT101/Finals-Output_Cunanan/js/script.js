// API Key 
const API_KEY = "d0768f91964ebc3c1d5f0b4004df42d4"; // Not recommended for actual implementation

// App state
let state = {
    user: null,
    currentTranslation: "06125adad2d5898a-01", // ASV by default
    currentBook: "GEN",
    currentChapter: 1,
    bibleData: {
        books: []
    }
};

// DOM elements
const loginModal = document.getElementById("login-modal");
const signupModal = document.getElementById("signup-modal");
const loginButton = document.getElementById("login-button");
const signupButton = document.getElementById("signup-button");
const profileButton = document.getElementById("profile-button");
const loginForm = document.getElementById("login-form");
const signupForm = document.getElementById("signup-form");
const logoutButton = document.getElementById("logout-button");
const loggedInActions = document.querySelector(".logged-in-actions");
const closeModalButtons = document.querySelectorAll(".close-modal");
const toggleFormLinks = document.querySelectorAll(".toggle-form");
const searchInput = document.getElementById("search-input");
const searchButton = document.getElementById("search-button");
const translationSelect = document.getElementById("translation-select");
const bookSelect = document.getElementById("book-select");
const chapterSelect = document.getElementById("chapter-select");
const prevChapterButton = document.getElementById("prev-chapter");
const nextChapterButton = document.getElementById("next-chapter");
const chapterText = document.getElementById("chapter-text");
const loader = document.querySelector(".loader");
const loginError = document.getElementById("login-error");
const signupError = document.getElementById("signup-error");
const oldTestamentList = document.getElementById("old-testament");
const newTestamentList = document.getElementById("new-testament");

// Initialize the app
document.addEventListener("DOMContentLoaded", function () {
    setupEventListeners();
    setupSearchFunctionality();
    checkAuth();
    
    // Get Bible versions and load initial books
    getBibleVersions().then(versions => {
        populateTranslationSelect(versions);
        
        // Load books for the selected translation
        return getBibleBooks(state.currentTranslation);
    }).then(books => {
        state.bibleData.books = books;
        initializeBooks(books);
        loadBibleContent();
    }).catch(error => {
        console.error("Error initializing app:", error);
        chapterText.innerHTML = '<p>Error loading Bible content. Please try again later.</p>';
        chapterText.style.display = 'block';
        loader.style.display = 'none';
    });
});

// Populate translations dropdown
function populateTranslationSelect(versions) {
    // Clear existing options
    translationSelect.innerHTML = "";

    // Add available versions to dropdown
    versions.forEach(version => {
        const option = document.createElement("option");
        option.value = version.id;
        option.textContent = `${version.name} (${version.language})`;
        translationSelect.appendChild(option);
    });
    
    // Set current translation
    translationSelect.value = state.currentTranslation;
}

// Initialize book lists based on API data
function initializeBooks(books) {
    // Clear existing content
    oldTestamentList.innerHTML = "";
    newTestamentList.innerHTML = "";
    bookSelect.innerHTML = "";


    // Separate Old Testament and New Testament
    const oldTestament = books.filter(book => isOldTestament(book.id));
    const newTestament = books.filter(book => !isOldTestament(book.id));
    
    // Add Old Testament books
    oldTestament.forEach((book) => {
        // Add to sidebar
        const listItem = document.createElement("li");
        listItem.innerHTML = `<a href="#" data-book="${book.id}"><i class="fas fa-bookmark"></i> ${book.name}</a>`;
        oldTestamentList.appendChild(listItem);

        // Add to dropdown
        const option = document.createElement("option");
        option.value = book.id;
        option.textContent = book.name;
        bookSelect.appendChild(option);
    });

    // Add New Testament books
    newTestament.forEach((book) => {
        // Add to sidebar
        const listItem = document.createElement("li");
        listItem.innerHTML = `<a href="#" data-book="${book.id}"><i class="fas fa-bookmark"></i> ${book.name}</a>`;
        newTestamentList.appendChild(listItem);

        // Add to dropdown
        const option = document.createElement("option");
        option.value = book.id;
        option.textContent = book.name;
        bookSelect.appendChild(option);
    });
    
    // Set listeners for sidebar book links
    document.querySelectorAll(".book-list a").forEach((link) => {
        link.addEventListener("click", function (e) {
            e.preventDefault();
            state.currentBook = this.dataset.book;
            state.currentChapter = 1;
            bookSelect.value = state.currentBook;
            updateChapterSelect();
            loadBibleContent();
        });
    });
    
    // Set current book selection
    bookSelect.value = state.currentBook;
}

// Helper function to determine if a book is in the Old Testament
function isOldTestament(bookId) {
    const oldTestamentBooks = [
        "GEN", "EXO", "LEV", "NUM", "DEU", "JOS", "JDG", "RUT", 
        "1SA", "2SA", "1KI", "2KI", "1CH", "2CH", "EZR", "NEH", 
        "EST", "JOB", "PSA", "PRO", "ECC", "SNG", "ISA", "JER", 
        "LAM", "EZK", "DAN", "HOS", "JOL", "AMO", "OBA", "JON", 
        "MIC", "NAM", "HAB", "ZEP", "HAG", "ZEC", "MAL"
    ];
    
    return oldTestamentBooks.includes(bookId);
}

// Set up event listeners
function setupEventListeners() {
    // Modal controls
    loginButton.addEventListener("click", () => openModal(loginModal));
    signupButton.addEventListener("click", () => openModal(signupModal));
    closeModalButtons.forEach((button) => {
        button.addEventListener("click", () => {
            closeModal(loginModal);
            closeModal(signupModal);
        });
    });

    // Toggle between login and signup forms
    toggleFormLinks.forEach((link) => {
        link.addEventListener("click", function () {
            const modalToShow = document.getElementById(this.dataset.show);
            closeModal(loginModal);
            closeModal(signupModal);
            openModal(modalToShow);
        });
    });

    // Form submissions
    loginForm.addEventListener("submit", handleLogin);
    signupForm.addEventListener("submit", handleSignup);
    logoutButton.addEventListener("click", handleLogout);

    // Bible navigation
    translationSelect.addEventListener("change", () => {
        state.currentTranslation = translationSelect.value;
        
        // Reload books for this translation
        getBibleBooks(state.currentTranslation).then(books => {
            state.bibleData.books = books;
            initializeBooks(books);
            loadBibleContent();
        }).catch(error => {
            console.error("Error loading books for translation:", error);
            showToast("Error loading books for this translation");
        });
    });

    bookSelect.addEventListener("change", () => {
        state.currentBook = bookSelect.value;
        state.currentChapter = 1;
        updateChapterSelect();
        loadBibleContent();
    });

    chapterSelect.addEventListener("change", () => {
        state.currentChapter = parseInt(chapterSelect.value);
        loadBibleContent();
    });

    prevChapterButton.addEventListener("click", navigateToPreviousChapter);
    nextChapterButton.addEventListener("click", navigateToNextChapter);

    // Window click to close modal
    window.addEventListener("click", function (e) {
        if (e.target === loginModal) closeModal(loginModal);
        if (e.target === signupModal) closeModal(signupModal);
    });
}

// Search functionality
function setupSearchFunctionality() {
    // Search button click handler
    searchButton.addEventListener("click", function() {
        performSearch();
    });
    
    // Enter key press handler for search input
    searchInput.addEventListener("keypress", function(e) {
        if (e.key === "Enter") {
            performSearch();
        }
    });
}

function performSearch() {
    const query = searchInput.value.trim();
    
    if (!query || query.length < 3) {
        showToast("Please enter at least 3 characters for search");
        return;
    }
    
    // Show loader
    chapterText.style.display = "none";
    loader.style.display = "block";
    
    // Perform the search
    searchBible(query);
}

// Update chapter select dropdown based on current book
function updateChapterSelect() {
    chapterSelect.innerHTML = "";
    
    // Find the current book from our state
    const book = state.bibleData.books.find(b => b.id === state.currentBook);
    
    if (book) {
        // Get the chapters for this book
        getBookChapters(state.currentTranslation, state.currentBook)
            .then(chapters => {
                // Populate chapter dropdown
                chapters.forEach(chapter => {
                    const option = document.createElement("option");
                    option.value = chapter.number;
                    option.textContent = `Chapter ${chapter.number}`;
                    chapterSelect.appendChild(option);
                });
                
                // Set current chapter
                chapterSelect.value = state.currentChapter;
            })
            .catch(error => {
                console.error("Error fetching chapters:", error);
                // Fallback - create some generic chapters if API fails
                createFallbackChapters();
            });
    } else {
        // Fallback if we don't have the book data
        createFallbackChapters();
    }
}

// Create fallback chapters when API fails
function createFallbackChapters() {
    // Create 30 chapters by default (most books have fewer)
    for (let i = 1; i <= 30; i++) {
        const option = document.createElement("option");
        option.value = i;
        option.textContent = `Chapter ${i}`;
        chapterSelect.appendChild(option);
    }
    chapterSelect.value = state.currentChapter;
}

// Load Bible content from API
function loadBibleContent() {
    // Show loader
    chapterText.style.display = "none";
    loader.style.display = "block";

    // Update UI selections
    bookSelect.value = state.currentBook;
    updateChapterSelect();

    // Make API request
    const url = `https://api.scripture.api.bible/v1/bibles/${state.currentTranslation}/chapters/${state.currentBook}.${state.currentChapter}`;

    fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`API request failed: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        displayBibleContent(data.data.content);
    })
    .catch(error => {
        console.error('Error fetching Bible content:', error);
        chapterText.innerHTML = '<p>Error loading Bible content. Please try again later.</p>';
        chapterText.style.display = 'block';
        loader.style.display = 'none';
    });
}

// Display Bible content
function displayBibleContent(content) {
    // Clear existing content
    chapterText.innerHTML = "";

    // Get current book name
    const currentBook = state.bibleData.books.find(book => book.id === state.currentBook);
    const bookName = currentBook ? currentBook.name : state.currentBook;

    // Add heading
    const heading = document.createElement("h2");
    heading.textContent = `${bookName} ${state.currentChapter}`;
    chapterText.appendChild(heading);

    // Handle the content based on what the API returns
    // API.Bible usually returns HTML content, so we can directly insert it
    const contentDiv = document.createElement("div");
    contentDiv.className = "bible-content";

    // Check if the API returned HTML or plain text
    if (content.includes('<') && content.includes('</')) {
        // HTML content - we need to modify it to add our verse formatting
        contentDiv.innerHTML = formatVerseHTML(content);
    } else {
        // Plain text content - format it ourselves
        contentDiv.innerHTML = formatVerseText(content, state.currentBook, state.currentChapter);
    }

    chapterText.appendChild(contentDiv);

    // Hide loader, show content
    loader.style.display = "none";
    chapterText.style.display = "block";
}

// Format HTML content from the API to add verse classes and data attributes
function formatVerseHTML(html) {
    // Parse the HTML
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    
    // Find all verse elements - different APIs might use different formats
    // API.Bible usually uses spans with data-verse attributes
    const verses = doc.querySelectorAll('[data-verse]');
    
    if (verses.length > 0) {
        verses.forEach(verse => {
            // Add verse class for styling
            verse.classList.add('verse');
            
            // Add data-verse-id attribute for our verse actions
            const verseNum = verse.getAttribute('data-verse');
            verse.setAttribute('data-verse-id', `${state.currentBook}-${state.currentChapter}_${verseNum}`);
        });
    } else {
        // If no verse elements found with data-verse, look for other common formats
        // Some APIs use verse numbers in superscript or spans with class 'verse-num'
        const potentialVerses = doc.querySelectorAll('p, span, div');
        
        potentialVerses.forEach(element => {
            const text = element.textContent;
            
            // Look for verse numbers (e.g., "1 In the beginning...")
            if (/^\d+\s/.test(text)) {
                const verseNum = text.match(/^\d+/)[0];
                
                // Create wrapper for verse
                const verseWrapper = doc.createElement('span');
                verseWrapper.className = 'verse';
                verseWrapper.setAttribute('data-verse-id', `${state.currentBook}-${state.currentChapter}_${verseNum}`);
                
                // Create verse number element
                const verseNumSpan = doc.createElement('span');
                verseNumSpan.className = 'verse-num';
                verseNumSpan.textContent = verseNum;
                
                // Get verse text without the number
                const verseText = text.replace(/^\d+\s/, '');
                
                // Add verse number and text to wrapper
                verseWrapper.appendChild(verseNumSpan);
                verseWrapper.appendChild(doc.createTextNode(' ' + verseText));
                
                // Replace original element with our verse wrapper
                element.parentNode.replaceChild(verseWrapper, element);
            }
        });
    }
    
    return doc.body.innerHTML;
}

// Format plain text content into verses with proper HTML
function formatVerseText(text, book, chapter) {
    let formattedText = '';
    
    // Split text by verse numbers (e.g., "1 In the beginning...", "2 And the earth...")
    const verses = text.split(/(?=\n\d+\s)/);
    
    verses.forEach(verse => {
        const trimmedVerse = verse.trim();
        
        // Skip empty verses
        if (!trimmedVerse) return;
        
        // Match verse number at the beginning
        const verseNumberMatch = trimmedVerse.match(/^(\d+)\s/);
        
        if (verseNumberMatch) {
            const verseNumber = verseNumberMatch[1];
            const verseText = trimmedVerse.substring(verseNumberMatch[0].length);
            
            // Create verse HTML
            formattedText += `
                <p class="verse" data-verse-id="${book}-${chapter}_${verseNumber}">
                    <span class="verse-num">${verseNumber}</span> ${verseText}
                </p>
            `;
        } else {
            // If no verse number found, just add the text as is
            formattedText += `<p>${trimmedVerse}</p>`;
        }
    });
    
    return formattedText;
}

// Navigate to previous chapter
function navigateToPreviousChapter() {
    if (state.currentChapter > 1) {
        // Previous chapter in same book
        state.currentChapter--;
    } else {
        // Last chapter of previous book
        const books = state.bibleData.books;
        const currentBookIndex = allBooks.findIndex(
            (book) => book.id === state.currentBook
        );
        
        if (currentBookIndex > 0) {
            // Get previous book
            const previousBook = books[currentBookIndex - 1];
            state.currentBook = previousBook.id;
            
            // Get chapters for the previous book to find the last chapter
            getBookChapters(state.currentTranslation, previousBook.id)
                .then(chapters => {
                    // Set to the last chapter of the previous book
                    state.currentChapter = chapters.length;
                    
                    // Update UI and load content
                    bookSelect.value = state.currentBook;
                    updateChapterSelect();
                    loadBibleContent();
                })
                .catch(error => {
                    console.error("Error getting chapters for previous book:", error);
                    // Fallback to chapter 1 if we can't determine last chapter
                    state.currentChapter = 1;
                    bookSelect.value = state.currentBook;
                    updateChapterSelect();
                    loadBibleContent();
                });  // We'll load content after the API call returns
        }
    }

    // Update UI and load content for same book, different chapter
    bookSelect.value = state.currentBook;
    updateChapterSelect();
    loadBibleContent();
}

// Navigate to next chapter
function navigateToNextChapter() {
    // Get chapters for current book to determine if we need to move to next book
    getBookChapters(state.currentTranslation, state.currentBook)
        .then(chapters => {
            if (state.currentChapter < chapters.length) {
                // Next chapter in same book
                state.currentChapter++;
                
                // Update UI and load content
                bookSelect.value = state.currentBook;
                updateChapterSelect();
                loadBibleContent();
            } else {
                // First chapter of next book
                const books = state.bibleData.books;
                const currentBookIndex = books.findIndex(book => book.id === state.currentBook);
                
                if (currentBookIndex < books.length - 1) {
                    // Move to next book, chapter 1
                    const nextBook = books[currentBookIndex + 1];
                    state.currentBook = nextBook.id;
                    state.currentChapter = 1;
                    
                    // Update UI and load content
                    bookSelect.value = state.currentBook;
                    updateChapterSelect();
                    loadBibleContent();
                } else {
                    showToast("You've reached the end of the Bible!");
                }
            }
        })
        .catch(error => {
            console.error("Error getting chapters for current book:", error);
            // Try to advance anyway (for robustness)
            state.currentChapter++;
            loadBibleContent();
        });
}

// Open modal
function openModal(modal) {
    modal.style.display = "block";
}

// Close modal
function closeModal(modal) {
    modal.style.display = "none";
    // Clear form fields and errors
    const forms = modal.querySelectorAll("form");
    forms.forEach((form) => form.reset());
    const alerts = modal.querySelectorAll(".alert");
    alerts.forEach((alert) => (alert.style.display = "none"));
}

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
            
            // Load user's saved data
            loadUserData();
            
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
    }, 1000);
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
    }, 1000);
}

// Initialize user data structures
function initializeUserData(email) {
    // Create empty data structures for new user
    const userData = {
        email: email,
        bookmarks: [],
        highlights: [],
        notes: []
    };
    
    // Save to localStorage
    const allUserData = JSON.parse(localStorage.getItem("bibleAppUserData") || "[]");
    allUserData.push(userData);
    localStorage.setItem("bibleAppUserData", JSON.stringify(allUserData));
    
    // Set in state
    state.bookmarks = [];
    state.highlights = [];
    state.notes = [];
}

// Load user data from localStorage
function loadUserData() {
    if (!state.user) return;
    
    const allUserData = JSON.parse(localStorage.getItem("bibleAppUserData") || "[]");
    const userData = allUserData.find(data => data.email === state.user.email);
    
    if (userData) {
        state.bookmarks = userData.bookmarks || [];
        state.highlights = userData.highlights || [];
        state.notes = userData.notes || [];
        
        // Apply to current chapter if loaded
        applyUserDataToChapter();
    }
}

// Save user data to localStorage
function saveUserData() {
    if (!state.user) return;
    
    const allUserData = JSON.parse(localStorage.getItem("bibleAppUserData") || "[]");
    let userData = allUserData.find(data => data.email === state.user.email);
    
    if (userData) {
        // Update existing user data
        userData.bookmarks = state.bookmarks;
        userData.highlights = state.highlights;
        userData.notes = state.notes;
    } else {
        // Create new user data
        userData = {
            email: state.user.email,
            bookmarks: state.bookmarks,
            highlights: state.highlights,
            notes: state.notes
        };
        allUserData.push(userData);
    }
    
    // Save back to localStorage
    localStorage.setItem("bibleAppUserData", JSON.stringify(allUserData));
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

// Show error message
function showError(element, message) {
    element.textContent = message;
    element.style.display = "block";

    // Hide error after 3 seconds
    setTimeout(() => {
        element.style.display = "none";
    }, 3000);
}

// Check if user is already logged in
function checkAuth() {
    const savedUser = localStorage.getItem("bibleAppUser");
    if (savedUser) {
        try {
            state.user = JSON.parse(savedUser);
            updateAuthUI();
            loadUserData();
        } catch (e) {
            console.error("Error parsing saved user:", e);
            localStorage.removeItem("bibleAppUser");
        }
    }
}

// Update UI based on authentication state
function updateAuthUI() {
    if (state.user) {
        // User is logged in
        loginButton.style.display = "none";
        signupButton.style.display = "none";
        loggedInActions.style.display = "flex";
        
        // Enable verse interactions
        setupVerseInteractions();
    } else {
        // User is logged out
        loginButton.style.display = "inline-block";
        signupButton.style.display = "inline-block";
        loggedInActions.style.display = "none";
    }
}

// Get available Bible versions
function getBibleVersions() {
    const url = "https://api.scripture.api.bible/v1/bibles";

    return fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`API request failed: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        // Process and return the Bible versions
        return data.data.map(bible => ({
            id: bible.id,
            name: bible.name,
            description: bible.description,
            language: bible.language.name
        }));
    })
    .catch(error => {
        console.error("Error fetching Bible versions:", error);
        // Return some default Bible versions
        return [
            { id: "06125adad2d5898a-01", name: "English Standard Version", language: "English" },
            { id: "de4e12af7f28f599-01", name: "King James Version", language: "English" },
            { id: "01b29f4b342acc35-01", name: "New Living Translation", language: "English"}
        ]
    })
}

// Get Bible books for a specific translation
function getBibleBooks(bibleId) {
    const url = `https://api.scripture.api.bible/v1/bibles/${bibleId}/books`;

    return fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`API request failed: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        // Process and return the Bible books
        return data.data.map(book => ({
            id: book.id,
            name: book.name,
            nameLong: book.nameLong,
            abbreviation: book.abbreviation
        }));
    })
    .catch(error => {
        console.error("Error fetching Bible books:", error);
        // Return some default books if API fails
        return getDefaultBooks();
    });
}

// Get chapters for a specific book
function getBookChapters(bibleId, bookId) {
    const url = `https://api.scripture.api.bible/v1/bibles/${bibleId}/books/${bookId}/chapters`;

    return fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`API request failed: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        // Process and return the chapters
        return data.data.map(chapter => ({
            id: chapter.id,
            number: parseInt(chapter.number) || chapter.number,
            reference: chapter.reference
        }));
    })
    .catch(error => {
        console.error(`Error fetching chapters for book ${bookId}:`, error);
        // Return default chapters (estimate based on common book lengths)
        return getDefaultChapters(bookId);
    });
}

// Search the Bible
function searchBible(query) {
    const url = `https://api.scripture.api.bible/v1/bibles/${state.currentTranslation}/search?query=${encodeURIComponent(query)}`;

    fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`API request failed: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        displaySearchResults(data.data);
    })
    .catch(error => {
        console.error("Error searching Bible:", error);
        chapterText.innerHTML = `<p>Error performing search. Please try again later.</p>`;
        chapterText.style.display = 'block';
        loader.style.display = 'none';
    });
}

// Display search results
function displaySearchResults(results) {
    // Clear existing content
    chapterText.innerHTML = "";

    // Create search results heading
    const heading = document.createElement("h2");
    heading.textContent = `Search Results for "${searchInput.value}"`;
    chapterText.appendChild(heading);

    // Check if there are results
    if (!results || !results.verses || results.verses.length === 0) {
        const noResults = document.createElement("p");
        noResults.textContent = "No results found. Try different search terms.";
        chapterText.appendChild(noResults);
        loader.style.display = "none";
        chapterText.style.display = "block";
        return;
    }

    // Display results count
    const count = document.createElement("p");
    count.className = "results-count";
    count.textContent = `Found ${results.total} results`;
    chapterText.appendChild(count);

    // Create results container
    const resultsContainer = document.createElement("div");
    resultsContainer.className = "search-results";

    // Add each search result
    results.verses.forEach(verse => {
        const resultItem = document.createElement("div");
        resultItem.className = "search-result-item";

        // Get book and chapter from reference
        const reference = verse.reference;
        const bookNameMatches = reference.match(/([1-3]?\s*[A-Za-z]+)/);
        const bookName = bookNameMatches ? bookNameMatches[0].trim() : '';
        
        // Find book ID from name
        const book = state.bibleData.books.find(b => 
            b.name.toLowerCase() === bookName.toLowerCase() || 
            b.nameLong?.toLowerCase() === bookName.toLowerCase() ||
            b.abbreviation?.toLowerCase() === bookName.toLowerCase()
        );
        
        // Extract chapter and verse numbers
        const chapterVerseMatch = reference.match(/\d+:\d+/);
        const [chapterNum, verseNum] = chapterVerseMatch ? chapterVerseMatch[0].split(':') : ['1', '1'];

        // Create reference element
        const referenceElem = document.createElement("h3");
        referenceElem.textContent = verse.reference;
        
        // Make reference clickable if we have the book data
        if (book) {
            referenceElem.className = "clickable-reference";
            referenceElem.addEventListener("click", () => {
                state.currentBook = book.id;
                state.currentChapter = parseInt(chapterNum);
                bookSelect.value = state.currentBook;
                updateChapterSelect();
                loadBibleContent();
            });
        }
        
        resultItem.appendChild(referenceElem);

        // Add verse text with highlighted search terms
        const text = document.createElement("p");
        text.innerHTML = highlightSearchTerms(verse.text, searchInput.value);
        resultItem.appendChild(text);

        resultsContainer.appendChild(resultItem);
    });

    chapterText.appendChild(resultsContainer);

    // Hide loader, show content
    loader.style.display = "none";
    chapterText.style.display = "block";
}

// Highlight search terms in text
function highlightSearchTerms(text, searchQuery) {
    // Create regex from search terms (escape special characters)
    const terms = searchQuery.split(' ')
        .map(term => term.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'))
        .filter(term => term.length > 2); // Only use terms with 3+ chars
    
    if (terms.length === 0) return text;
    
    const regex = new RegExp(`(${terms.join('|')})`, 'gi');
    return text.replace(regex, '<span class="search-highlight">$1</span>');
}

// Get default books if API fails
function getDefaultBooks() {
    return [
        // Old Testament
        { id: "GEN", name: "Genesis", nameLong: "The First Book of Moses, called Genesis", abbreviation: "Gen" },
        { id: "EXO", name: "Exodus", nameLong: "The Second Book of Moses, called Exodus", abbreviation: "Exo" },
        { id: "LEV", name: "Leviticus", nameLong: "The Third Book of Moses, called Leviticus", abbreviation: "Lev" },
        { id: "NUM", name: "Numbers", nameLong: "The Fourth Book of Moses, called Numbers", abbreviation: "Num" },
        { id: "DEU", name: "Deuteronomy", nameLong: "The Fifth Book of Moses, called Deuteronomy", abbreviation: "Deu" },
        { id: "JOS", name: "Joshua", nameLong: "The Book of Joshua", abbreviation: "Jos" },
        { id: "JDG", name: "Judges", nameLong: "The Book of Judges", abbreviation: "Jdg" },
        { id: "RUT", name: "Ruth", nameLong: "The Book of Ruth", abbreviation: "Rut" },
        { id: "1SA", name: "1 Samuel", nameLong: "The First Book of Samuel", abbreviation: "1Sa" },
        { id: "2SA", name: "2 Samuel", nameLong: "The Second Book of Samuel", abbreviation: "2Sa" },
        { id: "1KI", name: "1 Kings", nameLong: "The First Book of the Kings", abbreviation: "1Ki" },
        { id: "2KI", name: "2 Kings", nameLong: "The Second Book of the Kings", abbreviation: "2Ki" },
        { id: "1CH", name: "1 Chronicles", nameLong: "The First Book of the Chronicles", abbreviation: "1Ch" },
        { id: "2CH", name: "2 Chronicles", nameLong: "The Second Book of the Chronicles", abbreviation: "2Ch" },
        { id: "EZR", name: "Ezra", nameLong: "The Book of Ezra", abbreviation: "Ezr" },
        { id: "NEH", name: "Nehemiah", nameLong: "The Book of Nehemiah", abbreviation: "Neh" },
        { id: "EST", name: "Esther", nameLong: "The Book of Esther", abbreviation: "Est" },
        { id: "JOB", name: "Job", nameLong: "The Book of Job", abbreviation: "Job" },
        { id: "PSA", name: "Psalms", nameLong: "The Book of Psalms", abbreviation: "Psa" },
        { id: "PRO", name: "Proverbs", nameLong: "The Proverbs", abbreviation: "Pro" },
        { id: "ECC", name: "Ecclesiastes", nameLong: "Ecclesiastes", abbreviation: "Ecc" },
        { id: "SNG", name: "Song of Solomon", nameLong: "The Song of Solomon", abbreviation: "Sng" },
        { id: "ISA", name: "Isaiah", nameLong: "The Book of the Prophet Isaiah", abbreviation: "Isa" },
        { id: "JER", name: "Jeremiah", nameLong: "The Book of the Prophet Jeremiah", abbreviation: "Jer" },
        { id: "LAM", name: "Lamentations", nameLong: "The Lamentations of Jeremiah", abbreviation: "Lam" },
        { id: "EZK", name: "Ezekiel", nameLong: "The Book of the Prophet Ezekiel", abbreviation: "Ezk" },
        { id: "DAN", name: "Daniel", nameLong: "The Book of Daniel", abbreviation: "Dan" },
        { id: "HOS", name: "Hosea", nameLong: "Hosea", abbreviation: "Hos" },
        { id: "JOL", name: "Joel", nameLong: "Joel", abbreviation: "Jol" },
        { id: "AMO", name: "Amos", nameLong: "Amos", abbreviation: "Amo" },
        { id: "OBA", name: "Obadiah", nameLong: "Obadiah", abbreviation: "Oba" },
        { id: "JON", name: "Jonah", nameLong: "Jonah", abbreviation: "Jon" },
        { id: "MIC", name: "Micah", nameLong: "Micah", abbreviation: "Mic" },
        { id: "NAM", name: "Nahum", nameLong: "Nahum", abbreviation: "Nam" },
        { id: "HAB", name: "Habakkuk", nameLong: "Habakkuk", abbreviation: "Hab" },
        { id: "ZEP", name: "Zephaniah", nameLong: "Zephaniah", abbreviation: "Zep" },
        { id: "HAG", name: "Haggai", nameLong: "Haggai", abbreviation: "Hag" },
        { id: "ZEC", name: "Zechariah", nameLong: "Zechariah", abbreviation: "Zec" },
        { id: "MAL", name: "Malachi", nameLong: "Malachi", abbreviation: "Mal" },

        // New Testament
        { id: "MAT", name: "Matthew", nameLong: "The Gospel According to Matthew", abbreviation: "Mat" },
        { id: "MRK", name: "Mark", nameLong: "The Gospel According to Mark", abbreviation: "Mrk" },
        { id: "LUK", name: "Luke", nameLong: "The Gospel According to Luke", abbreviation: "Luk" },
        { id: "JHN", name: "John", nameLong: "The Gospel According to John", abbreviation: "Jhn" },
        { id: "ACT", name: "Acts", nameLong: "The Acts of the Apostles", abbreviation: "Act" },
        { id: "ROM", name: "Romans", nameLong: "The Epistle of Paul to the Romans", abbreviation: "Rom" },
        { id: "1CO", name: "1 Corinthians", nameLong: "The First Epistle of Paul to the Corinthians", abbreviation: "1Co" },
        { id: "2CO", name: "2 Corinthians", nameLong: "The Second Epistle of Paul to the Corinthians", abbreviation: "2Co" },
        { id: "GAL", name: "Galatians", nameLong: "The Epistle of Paul to the Galatians", abbreviation: "Gal" },
        { id: "EPH", name: "Ephesians", nameLong: "The Epistle of Paul to the Ephesians", abbreviation: "Eph" },
        { id: "PHP", name: "Philippians", nameLong: "The Epistle of Paul to the Philippians", abbreviation: "Php" },
        { id: "COL", name: "Colossians", nameLong: "The Epistle of Paul to the Colossians", abbreviation: "Col" },
        { id: "1TH", name: "1 Thessalonians", nameLong: "The First Epistle of Paul to the Thessalonians", abbreviation: "1Th" },
        { id: "2TH", name: "2 Thessalonians", nameLong: "The Second Epistle of Paul to the Thessalonians", abbreviation: "2Th" },
        { id: "1TI", name: "1 Timothy", nameLong: "The First Epistle of Paul to Timothy", abbreviation: "1Ti" },
        { id: "2TI", name: "2 Timothy", nameLong: "The Second Epistle of Paul to Timothy", abbreviation: "2Ti" },
        { id: "TIT", name: "Titus", nameLong: "The Epistle of Paul to Titus", abbreviation: "Tit" },
        { id: "PHM", name: "Philemon", nameLong: "The Epistle of Paul to Philemon", abbreviation: "Phm" },
        { id: "HEB", name: "Hebrews", nameLong: "The Epistle to the Hebrews", abbreviation: "Heb" },
        { id: "JAS", name: "James", nameLong: "The General Epistle of James", abbreviation: "Jas" },
        { id: "1PE", name: "1 Peter", nameLong: "The First Epistle General of Peter", abbreviation: "1Pe" },
        { id: "2PE", name: "2 Peter", nameLong: "The Second Epistle General of Peter", abbreviation: "2Pe" },
        { id: "1JN", name: "1 John", nameLong: "The First Epistle General of John", abbreviation: "1Jn" },
        { id: "2JN", name: "2 John", nameLong: "The Second Epistle of John", abbreviation: "2Jn" },
        { id: "3JN", name: "3 John", nameLong: "The Third Epistle of John", abbreviation: "3Jn" },
        { id: "JUD", name: "Jude", nameLong: "The General Epistle of Jude", abbreviation: "Jud" },
        { id: "REV", name: "Revelation", nameLong: "The Revelation of Jesus Christ", abbreviation: "Rev" }
    ];
}

// Get default chapters for a book if API fails
function getDefaultChapters(bookId) {
    // Default chapter counts for all Bible books
    const chapterCounts = {
        "GEN": 50, "EXO": 40, "LEV": 27, "NUM": 36, "DEU": 34, "JOS": 24, "JDG": 21, "RUT": 4,
        "1SA": 31, "2SA": 24, "1KI": 22, "2KI": 25, "1CH": 29, "2CH": 36, "EZR": 10, "NEH": 13,
        "EST": 10, "JOB": 42, "PSA": 150, "PRO": 31, "ECC": 12, "SNG": 8, "ISA": 66, "JER": 52,
        "LAM": 5, "EZK": 48, "DAN": 12, "HOS": 14, "JOL": 3, "AMO": 9, "OBA": 1, "JON": 4,
        "MIC": 7, "NAM": 3, "HAB": 3, "ZEP": 3, "HAG": 2, "ZEC": 14, "MAL": 4,
        "MAT": 28, "MRK": 16, "LUK": 24, "JHN": 21, "ACT": 28, "ROM": 16, "1CO": 16, "2CO": 13,
        "GAL": 6, "EPH": 6, "PHP": 4, "COL": 4, "1TH": 5, "2TH": 3, "1TI": 6, "2TI": 4,
        "TIT": 3, "PHM": 1, "HEB": 13, "JAS": 5, "1PE": 5, "2PE": 3, "1JN": 5, "2JN": 1,
        "3JN": 1, "JUD": 1, "REV": 22
    };
    
    const count = chapterCounts[bookId] || 1;
    const chapters = [];
    
    for (let i = 1; i <= count; i++) {
        chapters.push({
            id: `${bookId}.${i}`,
            number: i,
            reference: `${bookId} ${i}`
        });
    }
    
    return chapters;
}

// Add a toast notification system
function showToast(message, type = "info") {
    // Check if a toast container exists, create one if it doesn't
    let toastContainer = document.querySelector(".toast-container");
    if (!toastContainer) {
        toastContainer = document.createElement("div");
        toastContainer.className = "toast-container";
        document.body.appendChild(toastContainer);
    }
    
    // Create toast element
    const toast = document.createElement("div");
    toast.className = `toast toast-${type}`;
    toast.textContent = message;
    
    // Add toast to container
    toastContainer.appendChild(toast);
    
    // Show toast with animation
    setTimeout(() => {
        toast.classList.add("show");
    }, 10);
    
    // Remove toast after 3 seconds
    setTimeout(() => {
        toast.classList.remove("show");
        setTimeout(() => {
            toastContainer.removeChild(toast);
        }, 300);
    }, 3000);
}

// Add CSS for toast notifications
function addToastStyles() {
    const style = document.createElement("style");
    style.textContent = `
        .toast-container {
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 1000;
        }
        
        .toast {
            padding: 12px 20px;
            margin-bottom: 10px;
            border-radius: 4px;
            color: white;
            opacity: 0;
            transform: translateX(100%);
            transition: all 0.3s ease;
            max-width: 300px;
        }
        
        .toast.show {
            opacity: 1;
            transform: translateX(0);
        }
        
        .toast-info {
            background-color: #3498db;
        }
        
        .toast-success {
            background-color: #2ecc71;
        }
        
        .toast-warning {
            background-color: #f39c12;
        }
        
        .toast-error {
            background-color: #e74c3c;
        }
    `;
    document.head.appendChild(style);
}

// Add CSS for search results
function addSearchStyles() {
    const style = document.createElement("style");
    style.textContent = `
        .search-results {
            margin-top: 20px;
        }
        
        .search-result-item {
            margin-bottom: 20px;
            padding: 15px;
            border-radius: 5px;
            background-color: #f9f9f9;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        
        .search-result-item h3 {
            margin-top: 0;
            color: #3f51b5;
        }
        
        .clickable-reference {
            cursor: pointer;
            text-decoration: underline;
            color: #3f51b5;
        }
        
        .clickable-reference:hover {
            color: #1a237e;
        }
        
        .search-highlight {
            background-color: #ffeb3b;
            padding: 0 2px;
            border-radius: 2px;
        }
        
        .results-count {
            font-style: italic;
            color: #666;
            margin-bottom: 20px;
        }
    `;
    document.head.appendChild(style);
}

// Initialize additional features
function initializeAdditionalFeatures() {
    addToastStyles();
    addSearchStyles();
}

document.addEventListener("DOMContentLoaded", function() {
    initializeAdditionalFeatures();
});