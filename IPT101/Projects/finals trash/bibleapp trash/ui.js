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
    contentDiv.innerHTML = content;

    chapterText.appendChild(contentDiv);

    // Hide loader, show content
    loader.style.display = "none";
    chapterText.style.display = "block";

    setupVerseInteractions();
}

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
            resultItem.innerHTML = `
                <div class="result-reference">${verse.reference}</div>
                <div class="result-text">${verse.text}</div>
            `;

            // Add click handler to navigate to the verse
            resultItem.addEventListener('click', () => {
                navigateToReference(verse.reference);
            });

            resultsContainer.appendChild(resultItem);
        });

        chapterText.appendChild(resultsContainer);
    } else {
        const noResults = document.createElement('p');
        noResults.textContent = 'No results found. Try different keywords.';
        chapterText.appendChild(noResults);
    }
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

// Update UI based on authentication state
function updateAuthUI() {
    if (state.user) {
        // User is logged in
        loginButton.style.display = "none";
        signupButton.style.display = "none";
        loggedInActions.style.display = "flex";
        
        // Load user data
        loadUserData();
    } else {
        // User is logged out
        loginButton.style.display = "inline-block";
        signupButton.style.display = "inline-block";
        loggedInActions.style.display = "none";
    }
}