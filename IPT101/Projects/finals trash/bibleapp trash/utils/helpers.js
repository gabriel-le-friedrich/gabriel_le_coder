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
            loadUserData(); // Load user's bookmarks, highlights, etc.
        } catch (e) {
            console.error("Error parsing saved user:", e);
            localStorage.removeItem("bibleAppUser");
        }
    }
}

// User Data Management (for real app, these would interact with a backend)

// Save user data to localStorage
function saveUserData() {
    if (!state.user || !state.user.email) return;
    
    const userData = {
        bookmarks: state.bookmarks,
        highlights: state.highlights,
        notes: state.notes
    };
    
    localStorage.setItem(`bibleAppData_${state.user.email}`, JSON.stringify(userData));
}


// Apply user data to the current chapter view
function applyUserDataToChapter() {
    if (!state.user) return;
    
    // Apply highlights
    const highlights = state.highlights.filter(
        h => h.book === state.currentBook && h.chapter === state.currentChapter
    );
    
    highlights.forEach(highlight => {
        const verseElement = document.querySelector(`.verse[data-verse-id="${highlight.verse}"]`);
        if (verseElement) {
            verseElement.style.backgroundColor = highlight.color;
        }
    });
    
    // Mark bookmarked verses
    const bookmarks = state.bookmarks.filter(
        b => b.book === state.currentBook && b.chapter === state.currentChapter
    );
    
    bookmarks.forEach(bookmark => {
        const verseElement = document.querySelector(`.verse[data-verse-id="${bookmark.verse}"]`);
        if (verseElement) {
            const bookmarkIcon = document.createElement('i');
            bookmarkIcon.className = 'fas fa-bookmark bookmark-icon';
            verseElement.prepend(bookmarkIcon);
        }
    });
    
    // Mark verses with notes
    const notes = state.notes.filter(
        n => n.book === state.currentBook && n.chapter === state.currentChapter
    );
    
    notes.forEach(note => {
        const verseElement = document.querySelector(`.verse[data-verse-id="${note.verse}"]`);
        if (verseElement) {
            const noteIcon = document.createElement('i');
            noteIcon.className = 'fas fa-sticky-note note-icon';
            noteIcon.title = note.text;
            verseElement.prepend(noteIcon);
        }
    });
}