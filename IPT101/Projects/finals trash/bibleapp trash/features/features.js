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

// Show highlight color options
function showHighlightOptions(book, chapter, verse) {
    // Remove any existing highlight options
    const existingOptions = document.querySelector('.highlight-options');
    if (existingOptions) document.body.removeChild(existingOptions);
    
    // Create highlight color options
    const highlightOptions = document.createElement('div');
    highlightOptions.className = 'highlight-options';
    
    // Add color options
    const colors = [
        { name: 'yellow', class: 'color-yellow', value: 'rgba(255, 255, 0, 0.3)' },
        { name: 'green', class: 'color-green', value: 'rgba(0, 255, 0, 0.2)' },
        { name: 'blue', class: 'color-blue', value: 'rgba(0, 0, 255, 0.2)' },
        { name: 'pink', class: 'color-pink', value: 'rgba(255, 192, 203, 0.3)' },
        { name: 'orange', class: 'color-orange', value: 'rgba(255, 165, 0, 0.3)' }
    ];
    
    colors.forEach(color => {
        const colorOption = document.createElement('div');
        colorOption.className = `color-option ${color.class}`;
        colorOption.dataset.color = color.value;
        colorOption.dataset.colorName = color.name;
        
        colorOption.addEventListener('click', function() {
            applyHighlight(book, chapter, verse, this.dataset.color, this.dataset.colorName);
            document.body.removeChild(highlightOptions);
        });
        
        highlightOptions.appendChild(colorOption);
    });
    
    // Add "Remove highlight" option if already highlighted
    const isHighlighted = state.highlights.some(h => 
        h.book === book && h.chapter === parseInt(chapter) && h.verse === parseInt(verse)
    );
    
    if (isHighlighted) {
        const removeOption = document.createElement('div');
        removeOption.className = 'color-option';
        removeOption.style.backgroundColor = '#f1f1f1';
        removeOption.style.display = 'flex';
        removeOption.style.justifyContent = 'center';
        removeOption.style.alignItems = 'center';
        
        const removeIcon = document.createElement('i');
        removeIcon.className = 'fas fa-times';
        removeIcon.style.color = '#666';
        
        removeOption.appendChild(removeIcon);
        
        removeOption.addEventListener('click', function() {
            removeHighlight(book, chapter, verse);
            document.body.removeChild(highlightOptions);
        });
        
        highlightOptions.appendChild(removeOption);
    }
    
    // Find verse element to position the color picker
    const verseElement = document.querySelector(`.verse[data-verse-id*="_${verse}"]`);
    if (verseElement) {
        const rect = verseElement.getBoundingClientRect();
        
        // Position the color options
        highlightOptions.style.top = `${rect.bottom + window.scrollY}px`;
        highlightOptions.style.left = `${rect.left}px`;
        
        document.body.appendChild(highlightOptions);
        
        // Close options when clicking elsewhere
        function closeOptions(e) {
            if (!highlightOptions.contains(e.target)) {
                document.body.removeChild(highlightOptions);
                document.removeEventListener('click', closeOptions);
            }
        }
        
        // Add slight delay before enabling close on click
        setTimeout(() => {
            document.addEventListener('click', closeOptions);
        }, 100);
    }
}

// Apply highlight to verse
function applyHighlight(book, chapter, verse, color, colorName) {
    if (!state.user) {
        showToast('Please log in to highlight verses');
        return;
    }
    
    // Save to user data
    saveHighlight(book, parseInt(chapter), parseInt(verse), color)
        .then(() => {
            // Find verse element
            const verseElement = document.querySelector(`.verse[data-verse-id*="_${verse}"]`);
            if (verseElement) {
                // Remove any existing highlight classes
                verseElement.classList.remove('highlight-yellow', 'highlight-green', 
                                             'highlight-blue', 'highlight-pink', 'highlight-orange');
                
                // Apply new highlight class
                verseElement.classList.add(`highlight-${colorName}`);
                
                // Also set direct style for immediate feedback
                verseElement.style.backgroundColor = color;
                
                showToast('Verse highlighted');
            }
        })
        .catch(error => {
            console.error('Error applying highlight:', error);
            showToast('Failed to highlight verse');
        });
}

// Remove highlight from verse
function removeHighlight(book, chapter, verse) {
    if (!state.user) return;
    
    // Remove from state
    state.highlights = state.highlights.filter(h => 
        !(h.book === book && h.chapter === parseInt(chapter) && h.verse === parseInt(verse))
    );
    
    // Save to localStorage
    saveUserData();
    
    // Find verse element
    const verseElement = document.querySelector(`.verse[data-verse-id*="_${verse}"]`);
    if (verseElement) {
        // Remove highlight classes
        verseElement.classList.remove('highlight-yellow', 'highlight-green', 
                                     'highlight-blue', 'highlight-pink', 'highlight-orange');
        
        // Reset background color
        verseElement.style.backgroundColor = '';
        
        showToast('Highlight removed');
    }
}

// Show note editor
function showNoteEditor(book, chapter, verse) {
    if (!state.user) {
        showToast('Please log in to add notes');
        return;
    }
    
    // Check if there's an existing note
    let existingNote = '';
    const noteObj = state.notes.find(n => 
        n.book === book && n.chapter === parseInt(chapter) && n.verse === parseInt(verse)
    );
    
    if (noteObj) {
        existingNote = noteObj.text;
    }
    
    // Create note editor
    const noteEditor = document.createElement('div');
    noteEditor.className = 'note-editor';
    noteEditor.innerHTML = `
        <h3>Add Note</h3>
        <textarea id="note-text" placeholder="Enter your note here...">${existingNote}</textarea>
        <div class="note-editor-buttons">
            <button class="cancel-note">Cancel</button>
            <button class="save-note">Save</button>
        </div>
    `;
    
    document.body.appendChild(noteEditor);
    
    // Focus textarea
    document.getElementById('note-text').focus();
    
    // Add event listeners
    const cancelButton = noteEditor.querySelector('.cancel-note');
    const saveButton = noteEditor.querySelector('.save-note');
    
    cancelButton.addEventListener('click', () => {
        document.body.removeChild(noteEditor);
    });
    
    saveButton.addEventListener('click', () => {
        const noteText = document.getElementById('note-text').value.trim();
        
        if (noteText) {
            saveNote(book, parseInt(chapter), parseInt(verse), noteText)
                .then(() => {
                    showToast('Note saved');
                    document.body.removeChild(noteEditor);
                    applyUserDataToChapter();
                })
                .catch(error => {
                    console.error('Error saving note:', error);
                    showToast('Failed to save note');
                });
        } else {
            // If note is empty, remove it
            if (noteObj) {
                state.notes = state.notes.filter(n => 
                    !(n.book === book && n.chapter === parseInt(chapter) && n.verse === parseInt(verse))
                );
                saveUserData();
                showToast('Note removed');
                document.body.removeChild(noteEditor);
                applyUserDataToChapter();
            } else {
                document.body.removeChild(noteEditor);
            }
        }
    });
    
    // Close on Escape key
    document.addEventListener('keydown', function closeOnEsc(e) {
        if (e.key === 'Escape') {
            document.body.removeChild(noteEditor);
            document.removeEventListener('keydown', closeOnEsc);
        }
    });
}

// Copy verse text to clipboard
function copyVerseToClipboard(verseId) {
    const verseElement = document.querySelector(`.verse[data-verse-id="${verseId}"]`);
    
    if (verseElement) {
        const verseText = verseElement.textContent;
        const reference = `${getBookName(state.currentBook)} ${state.currentChapter}:${verseId.split('-')[1].split('_')[0]}`;
        const textToCopy = `${verseText} (${reference})`;
        
        // Use the Clipboard API
        navigator.clipboard.writeText(textToCopy)
            .then(() => {
                showToast('Verse copied to clipboard');
            })
            .catch(err => {
                console.error('Failed to copy verse:', err);
                showToast('Failed to copy verse');
                
                // Fallback method
                const textarea = document.createElement('textarea');
                textarea.value = textToCopy;
                document.body.appendChild(textarea);
                textarea.select();
                document.execCommand('copy');
                document.body.removeChild(textarea);
                showToast('Verse copied to clipboard');
            });
    }
}

// Share verse
function shareVerse(book, chapter, verse) {
    const bookName = getBookName(book);
    const reference = `${bookName} ${chapter}:${verse}`;
    const verseElement = document.querySelector(`.verse[data-verse-id*="_${verse}"]`);
    let verseText = '';
    
    if (verseElement) {
        verseText = verseElement.textContent;
    }
    
    // Check if Web Share API is available
    if (navigator.share) {
        navigator.share({
            title: `Bible Verse: ${reference}`,
            text: `${verseText} (${reference})`,
            url: window.location.href
        })
        .then(() => {
            showToast('Verse shared successfully');
        })
        .catch(error => {
            console.error('Error sharing verse:', error);
            showToast('Failed to share verse');
        });
    } else {
        // Fallback for browsers that don't support Web Share API
        copyVerseToClipboard(`${book}_${verse}`);
    }
}

// Get book name from ID
function getBookName(bookId) {
    const allBooks = [...bibleBooks.oldTestament, ...bibleBooks.newTestament];
    const book = allBooks.find(b => b.id === bookId);
    return book ? book.name : bookId;
}

// Process HTML content to make verses interactive
function processVerseElements() {
    const content = document.querySelector('.bible-content');
    if (!content) return;
    
    // Process verse elements
    const verseElements = content.querySelectorAll('[data-verse-id]');
    verseElements.forEach(verseElement => {
        // Add verse class if not already added
        if (!verseElement.classList.contains('verse')) {
            verseElement.classList.add('verse');
            
            // Add click event listener if not already added
            if (!verseElement.hasAttribute('data-processed')) {
                verseElement.setAttribute('data-processed', 'true');
                verseElement.addEventListener('click', function(e) {
                    e.preventDefault();
                    const verseId = this.dataset.verseId;
                    
                    // Prevent default if clicking on icons
                    if (e.target.tagName === 'I') return;
                    
                    // Show verse actions menu
                    showVerseActions(verseId, this.getBoundingClientRect());
                });
            }
        }
    });
    
    // Apply user data (bookmarks, highlights, notes)
    if (state.user) {
        applyUserDataToChapter();
    }
}

// Save a bookmark
function saveBookmark(book, chapter, verse) {
    if (!state.user) return Promise.reject("User not logged in");
    
    const bookmark = { 
        id: `${book}.${chapter}.${verse}`,
        book, 
        chapter, 
        verse,
        dateAdded: new Date().toISOString()
    };
    
    // Add to state
    state.bookmarks.push(bookmark);
    
    // Save to localStorage
    saveUserData();
    
    return Promise.resolve(bookmark);
}

// Remove a bookmark
function removeBookmark(book, chapter, verse) {
    if (!state.user) return Promise.reject("User not logged in");
    
    // Filter out the bookmark to remove
    state.bookmarks = state.bookmarks.filter(
        b => !(b.book === book && b.chapter === chapter && b.verse === verse)
    );
    
    // Save to localStorage
    saveUserData();
    
    return Promise.resolve({ success: true });
}

// Save a highlight
function saveHighlight(book, chapter, verse, color) {
    if (!state.user) return Promise.reject("User not logged in");
    
    const highlight = { 
        id: `${book}.${chapter}.${verse}`,
        book, 
        chapter, 
        verse, 
        color,
        dateAdded: new Date().toISOString()
    };
    
    // Check if verse is already highlighted
    const existingIndex = state.highlights.findIndex(
        h => h.book === book && h.chapter === chapter && h.verse === verse
    );
    
    if (existingIndex >= 0) {
        // Update existing highlight
        state.highlights[existingIndex] = highlight;
    } else {
        // Add new highlight
        state.highlights.push(highlight);
    }
    
    // Save to localStorage
    saveUserData();
    
    return Promise.resolve(highlight);
}

// Save a note
function saveNote(book, chapter, verse, text) {
    if (!state.user) return Promise.reject("User not logged in");
    
    const note = { 
        id: `${book}.${chapter}.${verse}`,
        book, 
        chapter, 
        verse, 
        text,
        dateAdded: new Date().toISOString(),
        lastUpdated: new Date().toISOString()
    };
    
    // Check if note already exists
    const existingIndex = state.notes.findIndex(
        n => n.book === book && n.chapter === chapter && n.verse === verse
    );
    
    if (existingIndex >= 0) {
        // Update existing note
        note.dateAdded = state.notes[existingIndex].dateAdded; // Preserve original date
        state.notes[existingIndex] = note;
    } else {
        // Add new note
        state.notes.push(note);
    }
    
    // Save to localStorage
    saveUserData();
    
    return Promise.resolve(note);
}

// Get all user bookmarks
function getBookmarks() {
    return Promise.resolve(state.bookmarks);
}

// Get all user highlights
function getHighlights() {
    return Promise.resolve(state.highlights);
}

// Get all user notes
function getNotes() {
    return Promise.resolve(state.notes);
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

function setupVerseInteractions() {
    // Wait a moment for verses to be added to the DOM
    setTimeout(() => {
        document.querySelectorAll('.verse').forEach(verse => {
            verse.addEventListener('click', function(e) {
                e.preventDefault();
                const verseId = this.dataset.verseId;
                
                // Prevent default if clicking on icons
                if (e.target.tagName === 'I') return;
                
                // Show verse actions menu
                showVerseActions(verseId, this.getBoundingClientRect());
            });
        });
    }, 200);
}

function showVerseActions(verseId, position) {
    // Remove any existing verse action menus
    const existingMenu = document.querySelector('.verse-actions');
    if (existingMenu) document.body.removeChild(existingMenu);
    
    // Create a new menu
    const actionsMenu = document.createElement('div');
    actionsMenu.className = 'verse-actions';
    
    // Add different options based on login state
    if (state.user) {
        actionsMenu.innerHTML = `
            <button data-action="highlight" data-verse="${verseId}">
                <i class="fas fa-highlighter"></i> Highlight
            </button>
            <button data-action="bookmark" data-verse="${verseId}">
                <i class="fas fa-bookmark"></i> Bookmark
            </button>
            <button data-action="note" data-verse="${verseId}">
                <i class="fas fa-sticky-note"></i> Add Note
            </button>
            <button data-action="copy" data-verse="${verseId}">
                <i class="fas fa-copy"></i> Copy
            </button>
            <button data-action="share" data-verse="${verseId}">
                <i class="fas fa-share-alt"></i> Share
            </button>
        `;
    } else {
        actionsMenu.innerHTML = `
            <button data-action="copy" data-verse="${verseId}">
                <i class="fas fa-copy"></i> Copy
            </button>
            <button data-action="share" data-verse="${verseId}">
                <i class="fas fa-share-alt"></i> Share
            </button>
            <div class="login-prompt">
                <a href="#" id="verse-action-login">Login</a> to bookmark, highlight or take notes
            </div>
        `;
    }

    // Position menu near verse
    actionsMenu.style.top = `${position.bottom + window.scrollY}px`;
    actionsMenu.style.left = `${position.left}px`;

    document.body.appendChild(actionsMenu);

    // Close menu when clicking elsewhere
    function closeMenu(e) {
        if (!actionsMenu.contains(e.target)) {
            document.body.removeChild(actionsMenu);
            document.removeEventListener('click', closeMenu);
        }
    }

    // Add slight delay before enabling close on click
    setTimeout(() => {
        document.addEventListener('click', closeMenu);
    }, 100);

    // Handle action clicks
    actionsMenu.addEventListener('click', function(e) {
        const button = e.target.closest('button');
        if (!button) return;
        
        const action = button.dataset.action;
        const verse = button.dataset.verse;
        
        if (action) {
            handleVerseAction(action, verse);
            document.body.removeChild(actionsMenu);
        }
    });
    
    // Handle login prompt
    const loginPrompt = actionsMenu.querySelector('#verse-action-login');
    if (loginPrompt) {
        loginPrompt.addEventListener('click', function(e) {
            e.preventDefault();
            document.body.removeChild(actionsMenu);
            openModal(loginModal);
        });
    }
}

function handleVerseAction(action, verseId) {
    // Parse verse ID into book, chapter, verse
    const [book, chapterVerse] = verseId.split('-');
    const [chapter, verse] = chapterVerse.split('_');

    // Now we have the correct book, chapter, and verse variables

    switch (action) {
        case 'highlight':
            showHighlightOptions(book, chapter, verse);
            break;
        case 'bookmark':
            saveBookmark(book, chapter, verse)
                .then(() => {
                    showToast('Verse bookmarked!');
                    applyUserDataToChapter();
                });
            break;
        case 'note':
            showNoteEditor(book, chapter, verse);
            break;
        case 'copy':
            copyVerseToClipboard(verseId);
            break;
        case 'share':
            shareVerse(book, chapter, verse);
            break;
    }
}
