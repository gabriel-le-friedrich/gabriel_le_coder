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
    // FIX: Properly parse the verse reference
    const book = state.currentBook;
    const chapter = state.currentChapter;
    const verse = verseId.split('-')[1].split('_')[0];
    
    // Now we have the correct book, chapter, and verse variables
    
    switch(action) {
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