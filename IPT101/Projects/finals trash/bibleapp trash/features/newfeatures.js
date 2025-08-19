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

// Initialize additional features
function initializeAdditionalFeatures() {
    // Add styles
    addToastStyles();
    addSearchStyles();
    
    // Create context menu for verses
    createVerseContextMenu();
    
    // Add additional keyboard shortcuts
    document.addEventListener("keydown", function(e) {
        // Next chapter: Alt + Right Arrow
        if (e.altKey && e.key === "ArrowRight") {
            navigateToNextChapter();
        }
        
        // Previous chapter: Alt + Left Arrow
        if (e.altKey && e.key === "ArrowLeft") {
            navigateToPreviousChapter();
        }
        
        // Focus search box: Ctrl + F
        if (e.ctrlKey && e.key === "f") {
            e.preventDefault(); // Prevent browser's find dialog
            searchInput.focus();
        }
    });
}

// Call this at the end of the document ready function
document.addEventListener("DOMContentLoaded", function() {
    // After the original initialization
    initializeAdditionalFeatures();
});