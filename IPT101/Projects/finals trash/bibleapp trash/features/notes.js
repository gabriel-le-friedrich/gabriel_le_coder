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

// Get all user notes
function getNotes() {
    return Promise.resolve(state.notes);
}