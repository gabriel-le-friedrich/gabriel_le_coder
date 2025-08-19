const API_KEY = '3e398def588c26eccfdb9b0c03e8113a'; // Not recommended in an actual website.
const BASE_URL = 'https://api.themoviedb.org/3';
const IMAGE_BASE_URL = 'https://image.tmdb.org/t/p/w500';

// DOM Elements
const searchInput = document.getElementById('search');
const searchButton = document.getElementById('search-button');
const moviesContainer = document.getElementById('movies');
const loadingElement = document.getElementById('loading');
const errorElement = document.getElementById('error');
const modal = document.getElementById('modal');
const closeModal = document.getElementById('close-modal');
const movieDetails = document.getElementById('movie-details');
const loginBtn = document.getElementById('login-btn');
const registerBtn = document.getElementById('register-btn');
const authSection = document.getElementById('auth-section');
const contentSection = document.getElementById('content-section');
const loginForm = document.getElementById('login-form');
const registerForm = document.getElementById('register-form');
const loginCancel = document.getElementById('login-cancel');
const registerCancel = document.getElementById('register-cancel');
const navRight = document.getElementById('nav-right');
const contentTabs = document.getElementById('content-tabs');
const favoritesTab = document.querySelector('.favorites-tab');
const favoritesContainer = document.getElementById('favorites-container');
const successMessage = document.getElementById('success-message');

// Auth state
let currentUser = null;
let authToken = null;
let favorites = [];

// Check if user is already logged in
function checkLoggedInUser() {
    const storedUser = localStorage.getItem('user');
    const storedToken = localStorage.getItem('token');

    if (storedUser && storedToken) {
        currentUser = JSON.parse(storedUser);
        authToken = storedToken;
        updateUIForLoggedInUser();
        return true;
    }
    return false;
}

// Update UI for logged in user
function updateUIForLoggedInUser() {
    navRight.innerHTML = `
        <span class="user-info">Welcome, ${currentUser.name}</span>
        <button id="logout-btn" class="danger">Logout</button>
    `;

    document.getElementById('logout-btn').addEventListener('click', logout);

    // Show favorites tab
    favoritesTab.style.display = 'block';
    loadFavorites();
}

// Tab functionality
document.querySelectorAll('.tab-btn').forEach(button => {
    button.addEventListener('click', function () {
        const tabId = this.getAttribute('data-tab');

        // First, handle auth tabs
        if (tabId === 'login' || tabId === 'register') {
            document.querySelectorAll('.tab-btn[data-tab="login"], .tab-btn[data-tab="register"]').forEach(btn => {
                btn.classList.remove('active');
            });
            document.getElementById('login-tab').classList.remove('active');
            document.getElementById('register-tab').classList.remove('active');

            this.classList.add('active');
            document.getElementById(`${tabId}-tab`).classList.add('active');
        }
        // Then, handle content tabs
        else if (tabId === 'search' || tabId === 'favorites') {
            document.querySelectorAll('.tab-btn[data-tab="search"], .tab-btn[data-tab="favorites"]').forEach(btn => {
                btn.classList.remove('active');
            });
            document.getElementById('search-tab').classList.remove('active');
            document.getElementById('favorites-tab').classList.remove('active');

            this.classList.add('active');
            document.getElementById(`${tabId}-tab`).classList.add('active');

            if (tabId === 'favorites' && currentUser) {
                loadFavorites();
            }
        }
    });
});

// Show auth section
function showAuthSection(tab = 'login') {
    contentSection.style.display = 'none';
    authSection.style.display = 'block';

    // Activate the right tab
    document.querySelectorAll('.tab-btn[data-tab="login"], .tab-btn[data-tab="register"]').forEach(btn => {
        btn.classList.remove('active');
    });
    document.getElementById('login-tab').classList.remove('active');
    document.getElementById('register-tab').classList.remove('active');

    document.querySelector(`.tab-btn[data-tab="${tab}"]`).classList.add('active');
    document.getElementById(`${tab}-tab`).classList.add('active');
}

// Hide auth section
function hideAuthSection() {
    authSection.style.display = 'none';
    contentSection.style.display = 'block';
}

// Register user
async function registerUser(event) {
    event.preventDefault();

    const name = document.getElementById('register-name').value;
    const email = document.getElementById('register-email').value;
    const password = document.getElementById('register-password').value;
    const confirmPassword = document.getElementById('register-confirm-password').value;

    // Basic validation
    if (password !== confirmPassword) {
        showErrorMessage('Passwords do not match');
        return;
    }

    try {
        // Simulate backend registration
        const users = JSON.parse(localStorage.getItem('users') || '[]');

        // Check if user already exists
        if (users.some(user => user.email === email)) {
            showErrorMessage('User with this email already exists');
            return;
        }

        // Create new user
        const newUser = {
            id: Date.now().toString(),
            name,
            email,
            password: btoa(password),
            favorites: []
        };

        users.push(newUser);
        localStorage.setItem('users', JSON.stringify(users));

        // Auto login after registration
        currentUser = {
            id: newUser.id,
            name: newUser.name,
            email: newUser.email,
            favorites: []
        };

        // Generate token
        authToken = btoa(`${email}:${password}:${Date.now()}`);

        // Store in localStorage
        localStorage.setItem('user', JSON.stringify(currentUser));
        localStorage.setItem('token', authToken);

        showSuccessMessage('Registration successful');
        hideAuthSection();
        updateUIForLoggedInUser();
    } catch (error) {
        showErrorMessage('Registration failed');
        console.error(error);
    }
}

// Login user
async function loginUser(event) {
    event.preventDefault();

    const email = document.getElementById('login-email').value;
    const password = document.getElementById('login-password').value;

    try {
        // Simulate backend login
        const users = JSON.parse(localStorage.getItem('users') || '[]');
        const user = users.find(u => u.email === email && u.password === btoa(password));

        if (!user) {
            showErrorMessage('Invalid email or password');
            return;
        }

        // Set current user
        currentUser = {
            id: user.id,
            name: user.name,
            email: user.email,
            favorites: user.favorites || []
        };

        // Generate token
        authToken = btoa(`${email}:${password}:${Date.now()}`);

        // Store in localStorage
        localStorage.setItem('user', JSON.stringify(currentUser));
        localStorage.setItem('token', authToken);

        showSuccessMessage('Login successful');
        hideAuthSection();
        updateUIForLoggedInUser();
    } catch (error) {
        showErrorMessage('Login failed');
        console.error(error);
    }
}

// Logout user
function logout() {
    localStorage.removeItem('user');
    localStorage.removeItem('token');
    currentUser = null;
    authToken = null;

    navRight.innerHTML = `
        <button id="login-btn" class="secondary">Login</button>
        <button id="register-btn" class="secondary">Register</button>
    `;

    document.getElementById('login-btn').addEventListener('click', () => showAuthSection('login'));
    document.getElementById('register-btn').addEventListener('click', () => showAuthSection('register'));

    // Hide favorites tab
    favoritesTab.style.display = 'none';

    // Switch to search tab if on favorites tab
    if (document.getElementById('favorites-tab').classList.contains('active')) {
        document.querySelector('.tab-btn[data-tab="search"]').click();
    }

    showSuccessMessage('Logged out successfully');
}

// Load user favorites
function loadFavorites() {
    if (!currentUser) return;

    try {
        document.getElementById('favorites-loading').style.display = 'block';

        // API call to fetch the user's favorites
        const users = JSON.parse(localStorage.getItem('users') || '[]');
        const user = users.find(u => u.id === currentUser.id);

        if (user && user.favorites && user.favorites.length > 0) {
            favorites = user.favorites;
            displayFavorites(favorites);
        } else {
            favoritesContainer.innerHTML = '<div class="empty-state">You don\'t have any favorite movies yet</div>';
        }
    } catch (error) {
        document.getElementById('favorites-error').textContent = 'Error loading favorites';
        document.getElementById('favorites-error').style.display = 'block';
        console.error(error);
    } finally {
        document.getElementById('favorites-loading').style.display = 'none';
    }
}

// Display favorites
function displayFavorites(favoriteMovies) {
    favoritesContainer.innerHTML = '';

    if (!favoriteMovies || favoriteMovies.length === 0) {
        favoritesContainer.innerHTML = '<div class="empty-state">You don\'t have any favorite movies yet</div>';
        return;
    }

    favoriteMovies.forEach(movie => {
        const movieElement = document.createElement('div');
        movieElement.classList.add('movie');
        movieElement.style.position = 'relative';
        movieElement.addEventListener('click', (event) => {
            // Prevent modal from opening when clicking the favorite button
            if (event.target.tagName !== 'BUTTON') {
                showMovieDetails(movie.id);
            }
        });

        const posterPath = movie.poster_path
            ? `${IMAGE_BASE_URL}${movie.poster_path}`
            : '/api/placeholder/200/300';

        movieElement.innerHTML = `
        <button class="favorite-btn active" data-id="${movie.id}">❤️</button>
        <img src="${posterPath}" alt="${movie.title}" onerror="this.src='/api/placeholder/200/300'">
        <div class="movie-info">
            <div class="movie-title">${movie.title}</div>
            <div class="movie-date">${movie.release_date || 'Unknown date'}</div>
        </div>
        `;

        favoritesContainer.appendChild(movieElement);
    });

    // Add event listeners to favorite buttons
    document.querySelectorAll('#favorites-container .favorite-btn').forEach(btn => {
        btn.addEventListener('click', function (event) {
            event.stopPropagation();
            const movieId = this.getAttribute('data-id');
            toggleFavorite(movieId);
        });
    });
}

// Toggle favorite status
async function toggleFavorite(movieId) {
    if (!currentUser) {
        showErrorMessage('Please login to add favorites');
        return;
    }

    try {
        // Get the movie data if not already in favorites
        let movie;

        // Check if movie exists in favorites
        const existingIndex = favorites.findIndex(m => m.id.toString() === movieId.toString());

        if (existingIndex !== -1) {
            // Remove from favorites
            favorites.splice(existingIndex, 1);
        } else {
            // Add to favorites - get movie details first
            const response = await fetch(`${BASE_URL}/movie/${movieId}?api_key=${API_KEY}&language=en-US`);
            movie = await response.json();

            favorites.push({
                id: movie.id,
                title: movie.title,
                poster_path: movie.poster_path,
                release_date: movie.release_date
            });
        }

        // Update local storage
        const users = JSON.parse(localStorage.getItem('users') || '[]');
        const userIndex = users.findIndex(u => u.id === currentUser.id);

        if (userIndex !== -1) {
            users[userIndex].favorites = favorites;
            localStorage.setItem('users', JSON.stringify(users));

            // Update current user
            currentUser.favorites = favorites;
            localStorage.setItem('user', JSON.stringify(currentUser));

            // Update UI
            const currentTab = document.querySelector('#content-tabs .tab-btn.active').getAttribute('data-tab');

            if (currentTab === 'favorites') {
                loadFavorites();
            } else {
                // Update favorite button on the search tab
                const favoriteBtn = document.querySelector(`#movies .favorite-btn[data-id="${movieId}"]`);
                if (favoriteBtn) {
                    existingIndex !== -1 ? favoriteBtn.classList.remove('active') : favoriteBtn.classList.add('active');
                }
            }
        }
    } catch (error) {
        showErrorMessage('Error updating favorites');
        console.error(error);
    }
}

// Event listeners
searchButton.addEventListener('click', searchMovies);
searchInput.addEventListener('keypress', (e) => {
    if (e.key === 'Enter') {
        searchMovies();
    }
});

closeModal.addEventListener('click', () => {
    modal.style.display = 'none';
});

window.addEventListener('click', (e) => {
    if (e.target === modal) {
        modal.style.display = 'none';
    }
});

loginBtn.addEventListener('click', () => showAuthSection('login'));
registerBtn.addEventListener('click', () => showAuthSection('register'));
loginCancel.addEventListener('click', hideAuthSection);
registerCancel.addEventListener('click', hideAuthSection);
loginForm.addEventListener('submit', loginUser);
registerForm.addEventListener('submit', registerUser);

// Fetch popular movies on load
window.addEventListener('DOMContentLoaded', () => {
    fetchPopularMovies();
    checkLoggedInUser();
});

async function fetchPopularMovies() {
    try {
        showLoading();
        const response = await fetch(`${BASE_URL}/movie/popular?api_key=${API_KEY}&language=en-US&page=1`);
        const data = await response.json();

        if (data.results && data.results.length > 0) {
            displayMovies(data.results);
        } else {
            showError('No movies found');
        }
    } catch (error) {
        showError('Error fetching popular movies');
        console.error(error);
    } finally {
        hideLoading();
    }
}

async function searchMovies() {
    const query = searchInput.value.trim();

    if (!query) {
        fetchPopularMovies();
        return;
    }

    try {
        showLoading();
        const response = await fetch(`${BASE_URL}/search/movie?api_key=${API_KEY}&language=en-US&query=${encodeURIComponent(query)}&page=1&include_adult=false`);
        const data = await response.json();

        if (data.results && data.results.length > 0) {
            displayMovies(data.results);
        } else {
            moviesContainer.innerHTML = '<div class="empty-state">No movies found. Try a different search.</div>';
        }
    } catch (error) {
        showError('Error searching for movies');
        console.error(error);
    } finally {
        hideLoading();
    }
}

function displayMovies(movies) {
    moviesContainer.innerHTML = '';

    movies.forEach(movie => {
        const movieElement = document.createElement('div');
        movieElement.classList.add('movie');
        movieElement.style.position = 'relative';
        movieElement.addEventListener('click', (event) => {
            // Prevent modal from opening when clicking the favorite button
            if (event.target.tagName !== 'BUTTON') {
                showMovieDetails(movie.id);
            }
        });

        const posterPath = movie.poster_path
            ? `${IMAGE_BASE_URL}${movie.poster_path}`
            : '/api/placeholder/200/300';

        // Check if movie is in favorites
        const isInFavorites = currentUser && favorites.some(m => m.id.toString() === movie.id.toString());

        movieElement.innerHTML = `
        ${currentUser ? `<button class="favorite-btn ${isInFavorites ? 'active' : ''}" data-id="${movie.id}">❤️</button>` : ''}
        <img src="${posterPath}" alt="${movie.title}" onerror="this.src='/api/placeholder/200/300'">
        <div class="movie-info">
            <div class="movie-title">${movie.title}</div>
            <div class="movie-date">${movie.release_date || 'Unknown date'}</div>
        </div>
        `;

        moviesContainer.appendChild(movieElement);
    });

    // Add event listeners to favorite buttons
    if (currentUser) {
        document.querySelectorAll('#movies .favorite-btn').forEach(btn => {
            btn.addEventListener('click', function (event) {
                event.stopPropagation();
                const movieId = this.getAttribute('data-id');
                toggleFavorite(movieId);
            });
        });
    }
}

async function showMovieDetails(movieId) {
    try {
        showLoading();
        const response = await fetch(`${BASE_URL}/movie/${movieId}?api_key=${API_KEY}&language=en-US`);
        const movie = await response.json();

        const posterPath = movie.poster_path
            ? `${IMAGE_BASE_URL}${movie.poster_path}`
            : '/api/placeholder/300/450';

        let genresHTML = '';
        if (movie.genres && movie.genres.length > 0) {
            genresHTML = movie.genres.map(genre => `<span class="badge">${genre.name}</span>`).join('');
        }

        // Check if movie is in favorites
        const isInFavorites = currentUser && favorites.some(m => m.id.toString() === movie.id.toString());

        movieDetails.innerHTML = `
        <div class="movie-details">
            <div class="movie-poster">
            <img src="${posterPath}" alt="${movie.title}" onerror="this.src='/api/placeholder/300/450'">
            ${currentUser ? `<button class="favorite-btn ${isInFavorites ? 'active' : ''}" style="position: absolute; top: 45px; left: 25px;" data-id="${movie.id}">❤️</button>` : ''}
            </div>
            <div class="movie-info-detailed">
            <h2 class="movie-title-large">${movie.title}</h2>
            <div class="movie-meta">
                ${movie.release_date ? `<div>Release Date: ${movie.release_date}</div>` : ''}
                ${movie.runtime ? `<div>Runtime: ${movie.runtime} minutes</div>` : ''}
                ${movie.vote_average ? `<div>Rating: ${movie.vote_average.toFixed(1)}/10</div>` : ''}
            </div>
            <div class="movie-overview">${movie.overview || 'No overview available'}</div>
            <div class="movie-genres">
                ${genresHTML || 'No genres available'}
            </div>
            </div>
        </div>
        `;

        // Add event listener to favorite button in modal
        if (currentUser) {
            const modalFavoriteBtn = movieDetails.querySelector('.favorite-btn');
            if (modalFavoriteBtn) {
                modalFavoriteBtn.addEventListener('click', function (event) {
                    event.stopPropagation();
                    const movieId = this.getAttribute('data-id');
                    toggleFavorite(movieId);

                    // Update button state
                    this.classList.toggle('active');
                });
            }
        }

        modal.style.display = 'block';
    } catch (error) {
        showError('Error fetching movie details');
        console.error(error);
    } finally {
        hideLoading();
    }
}

// Helper functions for showing/hiding elements
function showLoading() {
    loadingElement.style.display = 'block';
    errorElement.style.display = 'none';
}

function hideLoading() {
    loadingElement.style.display = 'none';
}

function showError(message) {
    errorElement.textContent = message;
    errorElement.style.display = 'block';
    moviesContainer.innerHTML = '';
}

function showErrorMessage(message) {
    successMessage.textContent = message;
    successMessage.style.display = 'block';
    successMessage.style.background = '#da3633';

    setTimeout(() => {
        successMessage.style.display = 'none';
    }, 3000);
}

function showSuccessMessage(message) {
    successMessage.textContent = message;
    successMessage.style.display = 'block';
    successMessage.style.background = '#238636';

    setTimeout(() => {
        successMessage.style.display = 'none';
    }, 3000);
}

// Token management functions
function getAuthHeader() {
    return authToken ? { 'Authorization': `Bearer ${authToken}` } : {};
}

function isTokenExpired() {
    // Check if the JWT token is expired
    return false;
}

function refreshToken() {
    // Refresh the token
    return Promise.resolve(authToken);
}

// Initialize the app
// Setup localStorage if it doesn't exist yet
if (!localStorage.getItem('users')) {
    localStorage.setItem('users', JSON.stringify([]));
}