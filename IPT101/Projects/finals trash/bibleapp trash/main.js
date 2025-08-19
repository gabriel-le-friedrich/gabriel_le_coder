// // DOM elements
// const loginModal = document.getElementById("login-modal");
// const signupModal = document.getElementById("signup-modal");
// const loginButton = document.getElementById("login-button");
// const signupButton = document.getElementById("signup-button");
// const profileButton = document.getElementById("profile-button");
// const loginForm = document.getElementById("login-form");
// const signupForm = document.getElementById("signup-form");
// const logoutButton = document.getElementById("logout-button");
// const loggedInActions = document.querySelector(".logged-in-actions");
// const closeModalButtons = document.querySelectorAll(".close-modal");
// const toggleFormLinks = document.querySelectorAll(".toggle-form");
// const searchInput = document.getElementById("search-input");
// const searchButton = document.getElementById("search-button");
// const translationSelect = document.getElementById("translation-select");
// const bookSelect = document.getElementById("book-select");
// const chapterSelect = document.getElementById("chapter-select");
// const prevChapterButton = document.getElementById("prev-chapter");
// const nextChapterButton = document.getElementById("next-chapter");
// const chapterText = document.getElementById("chapter-text");
// const loader = document.querySelector(".loader");
// const loginError = document.getElementById("login-error");
// const signupError = document.getElementById("signup-error");
// const oldTestamentList = document.getElementById("old-testament");
// const newTestamentList = document.getElementById("new-testament");

// // Initialize the app
// document.addEventListener("DOMContentLoaded", function () {
//     initializeBooks();
//     setupEventListeners();
//     setupSearchFunctionality();
//     checkAuth();
//     loadBibleContent();
// });

// function setupSearchFunctionality() {
//     // Search button click handler
//     searchButton.addEventListener("click", function() {
//         performSearch();
//     });
    
//     // Enter key press handler for search input
//     searchInput.addEventListener("keypress", function(e) {
//         if (e.key === "Enter") {
//             performSearch();
//         }
//     });
// }

// // Import from our modules
// import State, { initializeState } from './data/state.js';
// import { bibleBooks, getAllBooks } from './data/bibleData.js';
// import { API_KEY, getBibleVersions, getChapterText } from './api.js';
// import { setupUI, updateUI } from './ui.js';
// import { setupAuthEvents } from './auth.js';
// import { setupSearchFunctionality } from './features/search.js';

// // Initialize the app
// document.addEventListener("DOMContentLoaded", function() {
//     // Initialize state
//     initializeState();
    
//     // Setup UI elements
//     setupUI();
    
//     // Setup auth events
//     setupAuthEvents();
    
//     // Setup search functionality
//     setupSearchFunctionality();
    
//     // Load initial Bible content
//     loadBibleContent();
// });

// // This function could later be moved to navigation.js
// function loadBibleContent() {
//     // Implementation that uses imported functions
//     const bibleId = State.get('currentTranslation');
//     const bookId = State.get('currentBook');
//     const chapter = State.get('currentChapter');
//     const chapterId = `${bookId}.${chapter}`;
    
//     getChapterText(bibleId, chapterId)
//         .then(content => {
//             // Do something with the content
//             console.log("Content loaded!");
//         });
// }

// // Export anything needed by other modules
// export { loadBibleContent };

// main.js
import State, { initializeState } from './data/state.js';
import { bibleBooks } from './data/bibleData.js';
import { getChapterText } from './api.js';
import { setupUI, updateAuthUI } from './ui.js';
import { setupAuthEvents } from './auth.js';
import { setupSearchFunctionality } from './features/search.js';

// Initialize the app
document.addEventListener("DOMContentLoaded", function() {
    // Initialize state - Using initializeState
    const appState = initializeState();
    
    // Setup UI elements - Using setupUI
    setupUI();
    
    // Setup auth events - Using setupAuthEvents
    setupAuthEvents();
    
    // Setup search functionality - Using setupSearchFunctionality
    setupSearchFunctionality();
    
    // Update UI based on authentication state - Using updateAuthUI
    updateAuthUI();
    
    // Initialize the book select with the Bible books data - Using bibleBooks
    initializeBookSelect(bibleBooks);
    
    // Load initial Bible content
    loadBibleContent();
});

// Initialize book selection dropdown
function initializeBookSelect(books) {
    const bookSelect = document.getElementById("book-select");
    bookSelect.innerHTML = "";
    
    // Using the imported bibleBooks
    books.oldTestament.forEach(book => {
        const option = document.createElement("option");
        option.value = book.id;
        option.textContent = book.name;
        bookSelect.appendChild(option);
    });
    
    books.newTestament.forEach(book => {
        const option = document.createElement("option");
        option.value = book.id;
        option.textContent = book.name;
        bookSelect.appendChild(option);
    });
}

// Load Bible content - Using State and getChapterText
function loadBibleContent() {
    const bibleId = State.get('currentTranslation');
    const bookId = State.get('currentBook');
    const chapter = State.get('currentChapter');
    const chapterId = `${bookId}.${chapter}`;
    
    getChapterText(bibleId, chapterId)
        .then(content => {
            const chapterText = document.getElementById("chapter-text");
            chapterText.innerHTML = content;
            console.log("Content loaded!");
        })
        .catch(error => {
            console.error("Error loading content:", error);
        });
}

// Export anything needed by other modules
export { loadBibleContent };