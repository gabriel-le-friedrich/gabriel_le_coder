function performSearch() {
    const query = searchInput.value.trim();
    
    if (!query || query.length < 3) {
        showToast("Please enter at least 3 characters for search");
        return;
    }
    
    // Show loader
    chapterText.style.display = "none";
    loader.style.display = "block";
    
    // Perform the search
    searchBible(query);
}

function searchBible(query) {
    if (!query || query.length < 3) {
        showToast("Please enter at least 3 characters for search");
        loader.style.display = "none";
        chapterText.style.display = "block";
        return;
    }

    const url = `https://api.scripture.api.bible/v1/bibles/${state.currentTranslation}/search?query=${encodeURIComponent(query)}`;

    fetch(url, {
        headers: { 'api-key': API_KEY }
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`Search API request failed: ${response.status}`);
        }
        return response.json();
    })
    .then(data => {
        displaySearchResults(data.data.verses);
        loader.style.display = "none";
        chapterText.style.display = "block";
    })
    .catch(error => {
        console.error('Error searching Bible:', error);
        chapterText.innerHTML = '<p>Search failed. Please try again later.</p>';
        loader.style.display = "none";
        chapterText.style.display = "block";
    });
}