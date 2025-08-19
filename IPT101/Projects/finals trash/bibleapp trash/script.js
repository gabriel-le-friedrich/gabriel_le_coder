// API Key ()
const API_KEY = "d0768f91964ebc3c1d5f0b4004df42d4";

// Bible books data
const bibleBooks = {
    oldTestament: [
        { id: "GEN", name: "Genesis", chapters: 50 },
        { id: "EXO", name: "Exodus", chapters: 40 },
        { id: "LEV", name: "Leviticus", chapters: 27 },
        { id: "NUM", name: "Numbers", chapters: 36 },
        { id: "DEU", name: "Deuteronomy", chapters: 34 },
        { id: "JOS", name: "Joshua", chapters: 24 },
        { id: "JDG", name: "Judges", chapters: 21 },
        { id: "RUT", name: "Ruth", chapters: 4 },
        { id: "1SA", name: "1 Samuel", chapters: 31 },
        { id: "2SA", name: "2 Samuel", chapters: 24 },
        { id: "1KI", name: "1 Kings", chapters: 22 },
        { id: "2KI", name: "2 Kings", chapters: 25 },
        { id: "1CH", name: "1 Chronicles", chapters: 29 },
        { id: "2CH", name: "2 Chronicles", chapters: 36 },
        { id: "EZR", name: "Ezra", chapters: 10 },
        { id: "NEH", name: "Nehemiah", chapters: 13 },
        { id: "EST", name: "Esther", chapters: 10 },
        { id: "JOB", name: "Job", chapters: 42 },
        { id: "PSA", name: "Psalms", chapters: 150 },
        { id: "PRO", name: "Proverbs", chapters: 31 },
        { id: "ECC", name: "Ecclesiastes", chapters: 12 },
        { id: "SNG", name: "Song of Solomon", chapters: 8 },
        { id: "ISA", name: "Isaiah", chapters: 66 },
        { id: "JER", name: "Jeremiah", chapters: 52 },
        { id: "LAM", name: "Lamentations", chapters: 5 },
        { id: "EZK", name: "Ezekiel", chapters: 48 },
        { id: "DAN", name: "Daniel", chapters: 12 },
        { id: "HOS", name: "Hosea", chapters: 14 },
        { id: "JOL", name: "Joel", chapters: 3 },
        { id: "AMO", name: "Amos", chapters: 9 },
        { id: "OBA", name: "Obadiah", chapters: 1 },
        { id: "JON", name: "Jonah", chapters: 4 },
        { id: "MIC", name: "Micah", chapters: 7 },
        { id: "NAM", name: "Nahum", chapters: 3 },
        { id: "HAB", name: "Habakkuk", chapters: 3 },
        { id: "ZEP", name: "Zephaniah", chapters: 3 },
        { id: "HAG", name: "Haggai", chapters: 2 },
        { id: "ZEC", name: "Zechariah", chapters: 14 },
        { id: "MAL", name: "Malachi", chapters: 4 },
    ],
    newTestament: [
        { id: "MAT", name: "Matthew", chapters: 28 },
        { id: "MRK", name: "Mark", chapters: 16 },
        { id: "LUK", name: "Luke", chapters: 24 },
        { id: "JHN", name: "John", chapters: 21 },
        { id: "ACT", name: "Acts", chapters: 28 },
        { id: "ROM", name: "Romans", chapters: 16 },
        { id: "1CO", name: "1 Corinthians", chapters: 16 },
        { id: "2CO", name: "2 Corinthians", chapters: 13 },
        { id: "GAL", name: "Galatians", chapters: 6 },
        { id: "EPH", name: "Ephesians", chapters: 6 },
        { id: "PHP", name: "Philippians", chapters: 4 },
        { id: "COL", name: "Colossians", chapters: 4 },
        { id: "1TH", name: "1 Thessalonians", chapters: 5 },
        { id: "2TH", name: "2 Thessalonians", chapters: 3 },
        { id: "1TI", name: "1 Timothy", chapters: 6 },
        { id: "2TI", name: "2 Timothy", chapters: 4 },
        { id: "TIT", name: "Titus", chapters: 3 },
        { id: "PHM", name: "Philemon", chapters: 1 },
        { id: "HEB", name: "Hebrews", chapters: 13 },
        { id: "JAS", name: "James", chapters: 5 },
        { id: "1PE", name: "1 Peter", chapters: 5 },
        { id: "2PE", name: "2 Peter", chapters: 3 },
        { id: "1JN", name: "1 John", chapters: 5 },
        { id: "2JN", name: "2 John", chapters: 1 },
        { id: "3JN", name: "3 John", chapters: 1 },
        { id: "JUD", name: "Jude", chapters: 1 },
        { id: "REV", name: "Revelation", chapters: 22 },
    ],
};

// App state
let state = {
    user: null,
    currentTranslation: "06125adad2d5898a-01", // ESV by default
    currentBook: "GEN",
    currentChapter: 1,
    bookmarks: [],
    highlights: [],
    notes: [],
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
    initializeBooks();
    setupEventListeners();
    setupSearchFunctionality();
    checkAuth();
    loadBibleContent();
});

// Initialize book lists
function initializeBooks() {
    // Clear existing content
    oldTestamentList.innerHTML = "";
    newTestamentList.innerHTML = "";
    bookSelect.innerHTML = "";

    // Add Old Testament books
    bibleBooks.oldTestament.forEach((book) => {
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
    bibleBooks.newTestament.forEach((book) => {
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
        loadBibleContent();
    });

    bookSelect.addEventListener("change", () => {
        state.currentBook = bookSelect.value;
        state.currentChapter = 1;
        updateChapterSelect();
        loadBibleContent();
        setupVerseInteractions();
    });

    chapterSelect.addEventListener("change", () => {
        state.currentChapter = parseInt(chapterSelect.value);
        loadBibleContent();
    });

    prevChapterButton.addEventListener("click", navigateToPreviousChapter);
    nextChapterButton.addEventListener("click", navigateToNextChapter);

    // Sidebar book selection
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
    let book;

    // Find the current book in our data
    for (const testament in bibleBooks) {
        const foundBook = bibleBooks[testament].find(
            (b) => b.id === state.currentBook
        );
        if (foundBook) {
            book = foundBook;
            break;
        }
    }

    if (book) {
        for (let i = 1; i <= book.chapters; i++) {
            const option = document.createElement("option");
            option.value = i;
            option.textContent = `Chapter ${i}`;
            chapterSelect.appendChild(option);
        }
        chapterSelect.value = state.currentChapter;
    }
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
        
        // Apply user's highlights, bookmarks, and notes if logged in
        if (state.user) {
            setTimeout(applyUserDataToChapter, 100); // Allow time for the DOM to update
        }
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
    let bookName = "";
    for (const testament in bibleBooks) {
        const foundBook = bibleBooks[testament].find(
            (b) => b.id === state.currentBook
        );
        if (foundBook) {
            bookName = foundBook.name;
            break;
        }
    }

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

    // processVerseElements();
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
        const allBooks = [...bibleBooks.oldTestament, ...bibleBooks.newTestament];
        const currentBookIndex = allBooks.findIndex(
            (book) => book.id === state.currentBook
        );

        if (currentBookIndex > 0) {
            const previousBook = allBooks[currentBookIndex - 1];
            state.currentBook = previousBook.id;
            state.currentChapter = previousBook.chapters;
        }
    }

    // Update UI and load content
    bookSelect.value = state.currentBook;
    updateChapterSelect();
    loadBibleContent();
}

// Navigate to next chapter
function navigateToNextChapter() {
    const allBooks = [...bibleBooks.oldTestament, ...bibleBooks.newTestament];
    const currentBook = allBooks.find((book) => book.id === state.currentBook);

    if (state.currentChapter < currentBook.chapters) {
        // Next chapter in same book
        state.currentChapter++;
    } else {
        // First chapter of next book
        const currentBookIndex = allBooks.findIndex(
            (book) => book.id === state.currentBook
        );

        if (currentBookIndex < allBooks.length - 1) {
            const nextBook = allBooks[currentBookIndex + 1];
            state.currentBook = nextBook.id;
            state.currentChapter = 1;
        }
    }

    // Update UI and load content
    bookSelect.value = state.currentBook;
    updateChapterSelect();
    loadBibleContent();
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
            //loadUserData(); // Load user's bookmarks, highlights, etc.
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
        
        // Load user data
        // loadUserData();
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
        .then(response => response.json())
        .then(data => {
            // Process and return the Bible versions
            return data.data.map(bible => ({
                id: bible.id,
                name: bible.name,
                description: bible.description,
                language: bible.language.name
            }));
        });
}

/*
// Get books for a specific Bible version
function getBibleBooks(bibleId) {
    const url = `https://api.scripture.api.bible/v1/bibles/${bibleId}/books`;

    // In a real implementation:
    return fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
        .then(response => response.json())
        .then(data => {
            // Process and return the books
            return data.data.map(book => ({
                id: book.id,
                name: book.name,
                nameLong: book.nameLong,
                abbreviation: book.abbreviation
            }));
        });
}

// Get chapters for a specific book
function getBookChapters(bibleId, bookId) {
    const url = `https://api.scripture.api.bible/v1/bibles/${bibleId}/books/${bookId}/chapters`;

    // In a real implementation:

    return fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
        .then(response => response.json())
        .then(data => {
            // Process and return the chapters
            return data.data.map(chapter => ({
                id: chapter.id,
                number: chapter.number,
                reference: chapter.reference
            }));
        });
}

// Get verses for a specific chapter
function getChapterVerses(bibleId, chapterId) {
    const url = `https://api.scripture.api.bible/v1/bibles/${bibleId}/chapters/${chapterId}/verses`;

    // In a real implementation:

    return fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
        .then(response => response.json())
        .then(data => {
            // Process and return the verses
            return data.data.map(verse => ({
                id: verse.id,
                number: verse.number,
                reference: verse.reference
            }));
        });
}

// Get full text for a chapter
function getChapterText(bibleId, chapterId) {
    const url = `https://api.scripture.api.bible/v1/bibles/${bibleId}/chapters/${chapterId}?content-type=text&include-notes=false&include-titles=true&include-chapter-numbers=false&include-verse-numbers=true`;

    // In a real implementation:
    return fetch(url, {
        headers: {
            'api-key': API_KEY
        }
    })
        .then(response => response.json())
        .then(data => {
            return data.data.content;
        });
}
*/
// Search the Bible and display results
function searchBible(query) {
    if (!query || query.length < 3) {
        showToast("Please enter at least 3 characters for search");
        loader.style.display = "none";
        chapterText.style.display = "block";
        return;
    }

    const url = `https://api.scripture.api.bible/v1/bibles/${state.currentTranslation}/search?query=${encodeURIComponent(query)}`;

    fetch(url, {
        headers: { 'api-key': API_KEY }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`Search API request failed: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        displaySearchResults(data.data.verses);
        loader.style.display = "none";
        chapterText.style.display = "block";
    })
    .catch(error => {
        console.error('Error searching Bible:', error);
        chapterText.innerHTML = '<p>Search failed. Please try again later.</p>';
        loader.style.display = "none";
        chapterText.style.display = "block";
    });
}

// Display search results with enhanced formatting
function displaySearchResults(verses) {
    // Clear current content
    chapterText.innerHTML = '';

    // Add search results heading
    const heading = document.createElement('h2');
    heading.textContent = `Search Results for "${searchInput.value.trim()}"`;
    chapterText.appendChild(heading);

    // Display results
    if (verses && verses.length > 0) {
        const resultsContainer = document.createElement('div');
        resultsContainer.className = 'search-results';

        verses.forEach(verse => {
            const resultItem = document.createElement('div');
            resultItem.className = 'search-result';
            
            // Parse the reference to get book, chapter, verse
            const referenceParts = verse.reference.split(' ');
            let book = referenceParts[0];
            let chapterVerse = referenceParts[1].split(':');
            let chapter = parseInt(chapterVerse[0]);
            let verseNum = parseInt(chapterVerse[1]);
            
            // Handle multi-word book names like "1 Corinthians"
            if (referenceParts.length > 2) {
                book = referenceParts.slice(0, referenceParts.length - 1).join(' ');
                chapterVerse = referenceParts[referenceParts.length - 1].split(':');
                chapter = parseInt(chapterVerse[0]);
                verseNum = parseInt(chapterVerse[1]);
            }
            
            // Create the reference element
            const reference = document.createElement('h3');
            reference.className = 'verse-reference';
            reference.textContent = verse.reference;
            
            // Create the verse text element with highlighted search terms
            const text = document.createElement('p');
            text.className = 'verse-text';
            
            // Highlight the search term in the verse text
            const searchTerm = searchInput.value.trim().toLowerCase();
            let verseText = verse.text;
            
            if (searchTerm) {
                // Create a case-insensitive regular expression for the search term
                const regex = new RegExp(`(${searchTerm})`, 'gi');
                verseText = verseText.replace(regex, '<span class="highlight">$1</span>');
            }
            
            text.innerHTML = verseText;
            
            // Add a link to navigate to the full chapter
            const viewInContext = document.createElement('a');
            viewInContext.className = 'view-context';
            viewInContext.textContent = 'View in context';
            viewInContext.href = '#';
            viewInContext.addEventListener('click', function(e) {
                e.preventDefault();
                
                // Find the book ID from the book name
                const bookId = findBookIdByName(book);
                if (!bookId) {
                    showToast(`Could not find book: ${book}`);
                    return;
                }
                
                // Set state values
                state.currentBook = bookId;
                state.currentChapter = chapter;
                
                // Update UI selections
                bookSelect.value = state.currentBook;
                updateChapterSelect();
                
                // Load Bible content and scroll to verse when loaded
                loadBibleContent();
                
                // Add a small delay to allow content to load, then scroll to verse
                setTimeout(() => {
                    const verseElement = document.querySelector(`.verse[data-verse-id="${state.currentBook}-${state.currentChapter}_${verseNum}"]`);
                    if (verseElement) {
                        verseElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                        verseElement.classList.add('highlight-verse');
                        // Remove highlight after 3 seconds
                        setTimeout(() => {
                            verseElement.classList.remove('highlight-verse');
                        }, 3000);
                    }
                }, 1000);
            });
            
            // Append elements to the result item
            resultItem.appendChild(reference);
            resultItem.appendChild(text);
            resultItem.appendChild(viewInContext);
            
            // Add the result item to the container
            resultsContainer.appendChild(resultItem);
        });
        
        chapterText.appendChild(resultsContainer);
        
        // Add result count
        const resultCount = document.createElement('p');
        resultCount.className = 'result-count';
        resultCount.textContent = `Found ${verses.length} ${verses.length === 1 ? 'verse' : 'verses'} matching your search.`;
        chapterText.appendChild(resultCount);
    } else {
        // No results found
        const noResults = document.createElement('p');
        noResults.className = 'no-results';
        noResults.textContent = 'No verses found matching your search term. Please try a different search.';
        chapterText.appendChild(noResults);
    }
    
    // Scroll to the top of results
    chapterText.scrollTop = 0;
}

function findBookIdByName(bookName) {
    // Normalize book name to handle variations
    bookName = bookName.toLowerCase().trim();
    
    // First try exact match
    const allBooks = [...bibleBooks.oldTestament, ...bibleBooks.newTestament];
    let book = allBooks.find(b => b.name.toLowerCase() === bookName);
    
    // If no exact match, try partial match
    if (!book) {
        book = allBooks.find(b => {
            // Handle books with numbers like "1 John" vs "1John" vs "First John"
            const normalizedName = b.name.toLowerCase().replace(/\s+/g, '');
            const normalizedSearch = bookName.replace(/\s+/g, '');
            return normalizedName.includes(normalizedSearch) || normalizedSearch.includes(normalizedName);
        });
    }
    
    return book ? book.id : null;
}

function navigateToReference(reference) {
    // Parse reference format (like "John 3:16")
    const parts = reference.split(' ');
    let book = parts[0];
    let chapterVerse = parts[1].split(':');
    let chapter = parseInt(chapterVerse[0]);
    let verse = parseInt(chapterVerse[1]);
    
    // Handle books with spaces in their names (like "1 Corinthians")
    if (parts.length > 2) {
        book = parts.slice(0, parts.length - 1).join(' ');
        chapterVerse = parts[parts.length - 1].split(':');
        chapter = parseInt(chapterVerse[0]);
        verse = parseInt(chapterVerse[1]);
    }
    
    // Convert book name to book ID
    const allBooks = [...bibleBooks.oldTestament, ...bibleBooks.newTestament];
    const foundBook = allBooks.find(b => 
        b.name.toLowerCase() === book.toLowerCase() || 
        b.name.toLowerCase().includes(book.toLowerCase())
    );
    
    if (!foundBook) {
        showToast("Book not found: " + book);
        return;
    }
    
    // Set state and load content
    state.currentBook = foundBook.id;
    state.currentChapter = chapter;
    
    // Update UI
    bookSelect.value = state.currentBook;
    updateChapterSelect();
    
    // Load the chapter
    loadBibleContent().then(() => {
        // Scroll to verse
        setTimeout(() => {
            const verseElement = document.querySelector(`.verse[data-verse-id*="_${verse}"]`);
            if (verseElement) {
                verseElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
                verseElement.classList.add('highlight-verse');
                setTimeout(() => {
                    verseElement.classList.remove('highlight-verse');
                }, 3000);
            }
        }, 500);
    });
}

function showToast(message, duration = 3000) {
    // Remove any existing toast
    const existingToast = document.querySelector('.toast-message');
    if (existingToast) {
        document.body.removeChild(existingToast);
    }
    
    const toast = document.createElement('div');
    toast.className = 'toast-message';
    toast.textContent = message;
    
    document.body.appendChild(toast);
    
    // Show the toast
    setTimeout(() => {
        toast.classList.add('show');
    }, 10);
    
    // Hide after duration
    setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => {
            document.body.removeChild(toast);
        }, 300);
    }, duration);
}



/*

// Set up interactions with verses (highlighting, bookmarking, etc.)
function setupVerseInteractions() {
    // Add click handlers to verses for highlighting/bookmarking if logged in
    if (state.user) {
        const verses = document.querySelectorAll('.verse');
        verses.forEach(verse => {
            verse.addEventListener('click', function() {
                // Toggle highlight class
                this.classList.toggle('user-highlight');
                
                // Update state with highlight
                const verseId = this.getAttribute('data-verse-id');
                if (this.classList.contains('user-highlight')) {
                    // Add highlight
                    if (!state.highlights.includes(verseId)) {
                        state.highlights.push(verseId);
                        saveUserData();
                    }
                } else {
                    // Remove highlight
                    state.highlights = state.highlights.filter(id => id !== verseId);
                    saveUserData();
                }
            });
        });
    }
}

// Apply user's saved data to the current chapter
function applyUserDataToChapter() {
    if (!state.user) return;
    
    // Apply highlights
    state.highlights.forEach(verseId => {
        if (verseId.startsWith(`${state.currentBook}-${state.currentChapter}`)) {
            const verseElement = document.querySelector(`[data-verse-id="${verseId}"]`);
            if (verseElement) {
                verseElement.classList.add('user-highlight');
            }
        }
    });
    
    // Apply bookmarks (if we implement this feature)
    // Apply notes (if we implement this feature)
}
*/

/*
// Add bookmarking functionality
function addBookmark(verseId) {
    if (!state.user) {
        showToast("Please log in to bookmark verses", "warning");
        return;
    }
    
    if (!state.bookmarks.includes(verseId)) {
        state.bookmarks.push(verseId);
        saveUserData();
        showToast("Verse bookmarked", "success");
    } else {
        // Remove bookmark if it already exists
        state.bookmarks = state.bookmarks.filter(id => id !== verseId);
        saveUserData();
        showToast("Bookmark removed", "info");
    }
}

// Add note to a verse
function addNote(verseId, noteText) {
    if (!state.user) {
        showToast("Please log in to add notes", "warning");
        return;
    }
    
    // Check if note already exists
    const existingNoteIndex = state.notes.findIndex(note => note.verseId === verseId);
    
    if (existingNoteIndex !== -1) {
        // Update existing note
        state.notes[existingNoteIndex].text = noteText;
    } else {
        // Add new note
        state.notes.push({
            verseId,
            text: noteText,
            timestamp: new Date().toISOString()
        });
    }
    
    saveUserData();
    showToast("Note saved", "success");
}

// Create context menu for verses
function createVerseContextMenu() {
    // Create context menu element
    const contextMenu = document.createElement("div");
    contextMenu.id = "verse-context-menu";
    contextMenu.className = "context-menu";
    contextMenu.style.display = "none";
    
    // Add menu options
    contextMenu.innerHTML = `
        <div class="context-menu-item" id="highlight-verse">
            <i class="fas fa-highlighter"></i> Highlight
        </div>
        <div class="context-menu-item" id="bookmark-verse">
            <i class="fas fa-bookmark"></i> Bookmark
        </div>
        <div class="context-menu-item" id="add-note">
            <i class="fas fa-sticky-note"></i> Add Note
        </div>
        <div class="context-menu-item" id="copy-verse">
            <i class="fas fa-copy"></i> Copy Text
        </div>
    `;
    
    // Add to document
    document.body.appendChild(contextMenu);
    
    // Track current verse
    let currentVerse = null;
    
    // Add right-click handler to verses
    document.addEventListener("contextmenu", function(e) {
        const verse = e.target.closest(".verse");
        if (verse) {
            e.preventDefault();
            currentVerse = verse;
            
            // Position menu at mouse position
            contextMenu.style.top = `${e.clientY}px`;
            contextMenu.style.left = `${e.clientX}px`;
            contextMenu.style.display = "block";
        }
    });
    
    // Hide menu when clicking elsewhere
    document.addEventListener("click", function(e) {
        if (!e.target.closest("#verse-context-menu")) {
            contextMenu.style.display = "none";
        }
    });
    
    // Handle menu item clicks
    document.getElementById("highlight-verse").addEventListener("click", function() {
        if (currentVerse) {
            currentVerse.classList.toggle("user-highlight");
            const verseId = currentVerse.getAttribute("data-verse-id");
            
            if (currentVerse.classList.contains("user-highlight")) {
                // Add highlight
                if (!state.highlights.includes(verseId)) {
                    state.highlights.push(verseId);
                    saveUserData();
                }
            } else {
                // Remove highlight
                state.highlights = state.highlights.filter(id => id !== verseId);
                saveUserData();
            }
        }
        contextMenu.style.display = "none";
    });
    
    document.getElementById("bookmark-verse").addEventListener("click", function() {
        if (currentVerse) {
            const verseId = currentVerse.getAttribute("data-verse-id");
            addBookmark(verseId);
        }
        contextMenu.style.display = "none";
    });
    
    document.getElementById("add-note").addEventListener("click", function() {
        if (currentVerse) {
            const verseId = currentVerse.getAttribute("data-verse-id");
            showNoteModal(verseId, currentVerse.textContent);
        }
        contextMenu.style.display = "none";
    });
    
    document.getElementById("copy-verse").addEventListener("click", function() {
        if (currentVerse) {
            // Copy verse text to clipboard
            const verseText = currentVerse.textContent;
            navigator.clipboard.writeText(verseText)
                .then(() => showToast("Verse copied to clipboard", "success"))
                .catch(() => showToast("Failed to copy text", "error"));
        }
        contextMenu.style.display = "none";
    });
}

// Show note modal for adding/editing notes
function showNoteModal(verseId, verseText) {
    // Check if user is logged in
    if (!state.user) {
        showToast("Please log in to add notes", "warning");
        return;
    }
    
    // Check if note modal exists, create if not
    let noteModal = document.getElementById("note-modal");
    if (!noteModal) {
        noteModal = document.createElement("div");
        noteModal.id = "note-modal";
        noteModal.className = "modal";
        
        noteModal.innerHTML = `
            <div class="modal-content">
                <span class="close-modal">&times;</span>
                <h2>Add Note</h2>
                <div id="verse-reference"></div>
                <div id="verse-text" class="verse-preview"></div>
                <form id="note-form">
                    <div class="form-group">
                        <label for="note-text">Your Note:</label>
                        <textarea id="note-text" rows="4"></textarea>
                    </div>
                    <button type="submit" class="btn btn-primary">Save Note</button>
                </form>
            </div>
        `;
        
        document.body.appendChild(noteModal);
        
        // Add event listeners for the note modal
        const closeButton = noteModal.querySelector(".close-modal");
        closeButton.addEventListener("click", () => {
            closeModal(noteModal);
        });
        
        const noteForm = document.getElementById("note-form");
        noteForm.addEventListener("submit", function(e) {
            e.preventDefault();
            const noteText = document.getElementById("note-text").value;
            const currentVerseId = noteForm.getAttribute("data-verse-id");
            
            if (noteText.trim()) {
                addNote(currentVerseId, noteText);
                closeModal(noteModal);
            } else {
                showToast("Please enter a note", "warning");
            }
        });
    }
    
    // Get existing note if any
    const existingNote = state.notes.find(note => note.verseId === verseId);
    
    // Update modal content
    document.getElementById("verse-reference").textContent = verseId.replace('_', ':');
    document.getElementById("verse-text").textContent = verseText;
    document.getElementById("note-text").value = existingNote ? existingNote.text : '';
    document.getElementById("note-form").setAttribute("data-verse-id", verseId);
    
    // Show modal
    openModal(noteModal);
}
*/