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

// Get all user highlights
function getHighlights() {
    return Promise.resolve(state.highlights);
}

