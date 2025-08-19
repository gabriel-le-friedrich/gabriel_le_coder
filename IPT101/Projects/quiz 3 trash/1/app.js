// Unsplash API Implementation
const UNSPLASH_ACCESS_KEY = 'YOUR_UNSPLASH_ACCESS_KEY'; // Replace with your actual Unsplash API key

// API endpoint URLs
const ENDPOINTS = {
  search: 'https://api.unsplash.com/search/photos',
  random: 'https://api.unsplash.com/photos/random',
  popular: 'https://api.unsplash.com/photos'
};

// Fetch photos from Unsplash based on search query
async function searchPhotos(query, page = 1, perPage = 12) {
  try {
    const url = new URL(ENDPOINTS.search);
    url.searchParams.append('query', query);
    url.searchParams.append('page', page);
    url.searchParams.append('per_page', perPage);
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Client-ID ${UNSPLASH_ACCESS_KEY}`
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    const data = await response.json();
    return data.results;
  } catch (error) {
    console.error('Error fetching photos:', error);
    displayError(error.message);
    return [];
  }
}

// Fetch random photos from Unsplash
async function getRandomPhotos(count = 12) {
  try {
    const url = new URL(ENDPOINTS.random);
    url.searchParams.append('count', count);
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Client-ID ${UNSPLASH_ACCESS_KEY}`
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error fetching random photos:', error);
    displayError(error.message);
    return [];
  }
}

// Fetch popular photos from Unsplash
async function getPopularPhotos(page = 1, perPage = 12, orderBy = 'popular') {
  try {
    const url = new URL(ENDPOINTS.popular);
    url.searchParams.append('page', page);
    url.searchParams.append('per_page', perPage);
    url.searchParams.append('order_by', orderBy);
    
    const response = await fetch(url, {
      headers: {
        'Authorization': `Client-ID ${UNSPLASH_ACCESS_KEY}`
      }
    });
    
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    
    return await response.json();
  } catch (error) {
    console.error('Error fetching popular photos:', error);
    displayError(error.message);
    return [];
  }
}

// Display images in the gallery
function displayImages(photos) {
  const gallery = document.getElementById('photo-gallery');
  gallery.innerHTML = ''; // Clear existing images
  
  if (photos.length === 0) {
    gallery.innerHTML = '<p class="no-results">No photos found. Try another search term.</p>';
    return;
  }
  
  photos.forEach(photo => {
    const photoCard = document.createElement('div');
    photoCard.className = 'photo-card';
    
    const img = document.createElement('img');
    img.src = photo.urls.small;
    img.alt = photo.alt_description || 'Unsplash Photo';
    img.loading = 'lazy';
    
    const photoInfo = document.createElement('div');
    photoInfo.className = 'photo-info';
    
    const photographer = document.createElement('p');
    photographer.className = 'photographer';
    photographer.textContent = `Photo by: ${photo.user.name}`;
    
    const likes = document.createElement('span');
    likes.className = 'likes';
    likes.innerHTML = `<i class="fas fa-heart"></i> ${photo.likes}`;
    
    photoInfo.appendChild(photographer);
    photoInfo.appendChild(likes);
    
    photoCard.appendChild(img);
    photoCard.appendChild(photoInfo);
    
    // Add click event to open photo in full size
    photoCard.addEventListener('click', () => {
      window.open(photo.links.html, '_blank');
    });
    
    gallery.appendChild(photoCard);
  });
  
  // Show gallery and hide loader
  document.getElementById('loader').style.display = 'none';
  gallery.style.display = 'grid';
}

// Display error message
function displayError(message) {
  const errorDiv = document.getElementById('error-message');
  errorDiv.textContent = `Error: ${message}`;
  errorDiv.style.display = 'block';
  document.getElementById('loader').style.display = 'none';
  
  // Hide error after 5 seconds
  setTimeout(() => {
    errorDiv.style.display = 'none';
  }, 5000);
}

// Event listeners for form submission and buttons
document.addEventListener('DOMContentLoaded', () => {
  // Initial load with random photos
  showLoader();
  getRandomPhotos().then(photos => {
    displayImages(photos);
  });
  
  // Search form submission
  document.getElementById('search-form').addEventListener('submit', async (e) => {
    e.preventDefault();
    const searchInput = document.getElementById('search-input');
    const query = searchInput.value.trim();
    
    if (!query) return;
    
    showLoader();
    const photos = await searchPhotos(query);
    displayImages(photos);
    updateActiveButton('search');
  });
  
  // Random photos button
  document.getElementById('random-btn').addEventListener('click', async () => {
    showLoader();
    const photos = await getRandomPhotos();
    displayImages(photos);
    updateActiveButton('random');
  });
  
  // Popular photos button
  document.getElementById('popular-btn').addEventListener('click', async () => {
    showLoader();
    const photos = await getPopularPhotos();
    displayImages(photos);
    updateActiveButton('popular');
  });
});

// Show loading indicator
function showLoader() {
  document.getElementById('photo-gallery').style.display = 'none';
  document.getElementById('loader').style.display = 'block';
}

// Update active state of nav buttons
function updateActiveButton(activeButton) {
  const buttons = document.querySelectorAll('.nav-button');
  buttons.forEach(button => {
    button.classList.remove('active');
    if (button.id === `${activeButton}-btn`) {
      button.classList.add('active');
    }
  });
}