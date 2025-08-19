// Display search results with enhanced formatting
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
            
            // Parse the reference to get book, chapter, verse
            const referenceParts = verse.reference.split(' ');
            let book = referenceParts[0];
            let chapterVerse = referenceParts[1].split(':');
            let chapter = parseInt(chapterVerse[0]);
            let verseNum = parseInt(chapterVerse[1]);
            
            // Handle multi-word book names like "1 Corinthians"
            if (referenceParts.length > 2) {
                book = referenceParts.slice(0, referenceParts.length - 1).join(' ');
                chapterVerse = referenceParts[referenceParts.length - 1].split(':');
                chapter = parseInt(chapterVerse[0]);
                verseNum = parseInt(chapterVerse[1]);
            }
            
            // Create the reference element
            const reference = document.createElement('h3');
            reference.className = 'verse-reference';
            reference.textContent = verse.reference;
            
            // Create the verse text element with highlighted search terms
            const text = document.createElement('p');
            text.className = 'verse-text';
            
            // Highlight the search term in the verse text
            const searchTerm = searchInput.value.trim().toLowerCase();
            let verseText = verse.text;
            
            if (searchTerm) {
                // Create a case-insensitive regular expression for the search term
                const regex = new RegExp(`(${searchTerm})`, 'gi');
                verseText = verseText.replace(regex, '<span class="highlight">$1</span>');
            }
            
            text.innerHTML = verseText;
            
            // Add a link to navigate to the full chapter
            const viewInContext = document.createElement('a');
            viewInContext.className = 'view-context';
            viewInContext.textContent = 'View in context';
            viewInContext.href = '#';
            viewInContext.addEventListener('click', function(e) {
                e.preventDefault();
                // Navigate to the full chapter
                bookSelect.value = getBookValue(book);
                chapterSelect.value = chapter;
                verseToHighlight = verseNum; // Global variable to highlight this verse when chapter loads
                loadChapter();
            });
            
            // Append elements to the result item
            resultItem.appendChild(reference);
            resultItem.appendChild(text);
            resultItem.appendChild(viewInContext);
            
            // Add the result item to the container
            resultsContainer.appendChild(resultItem);
        });
        
        chapterText.appendChild(resultsContainer);
        
        // Add result count
        const resultCount = document.createElement('p');
        resultCount.className = 'result-count';
        resultCount.textContent = `Found ${verses.length} ${verses.length === 1 ? 'verse' : 'verses'} matching your search.`;
        chapterText.appendChild(resultCount);
    } else {
        // No results found
        const noResults = document.createElement('p');
        noResults.className = 'no-results';
        noResults.textContent = 'No verses found matching your search term. Please try a different search.';
        chapterText.appendChild(noResults);
    }
    
    // Scroll to the top of results
    chapterText.scrollTop = 0;
}