// API Key ()
export const API_KEY = "d0768f91964ebc3c1d5f0b4004df42d4";

// Get available Bible versions
export function getBibleVersions() {
    const url = "https://api.scripture.api.bible/v1/bibles";

    // In a real implementation:

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

// Get books for a specific Bible version
export function getBibleBooks(bibleId) {
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
export function getBookChapters(bibleId, bookId) {
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
export function getChapterVerses(bibleId, chapterId) {
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
export function getChapterText(bibleId, chapterId) {
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