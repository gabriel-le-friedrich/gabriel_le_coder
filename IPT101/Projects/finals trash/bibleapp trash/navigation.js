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