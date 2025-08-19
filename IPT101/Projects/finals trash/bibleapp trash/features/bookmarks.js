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

// Get all user bookmarks
function getBookmarks() {
    return Promise.resolve(state.bookmarks);
}