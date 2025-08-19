document.addEventListener('DOMContentLoaded', function() {
    const card = document.getElementById('card');
    const web = document.getElementById('web');
    const dot_carousel = document.getElementById('dot-carousel');
    const arr_carousel = document.getElementById('arrow-carousel');
    const pullButton = document.getElementById('pullButton');
    
    // Add click event listener to the button
    pullButton.addEventListener('click', fetchRandomUser);
    
    function fetchRandomUser() {
        // Disable button and show loading state
        pullButton.disabled = true;
        pullButton.textContent = 'Pulling...';
        
        // Show loading spinner
        card.innerHTML = `
            <div class="loading">
                <div class="spinner"></div>
                <p>Summoning user...</p>
            </div>
        `;
        
        // Add sparkle effects during pull
        addSparkles();
        
        // Fetch data from randomuser.me API
        fetch('https://randomuser.me/api/')
            .then(response => {
                if (!response.ok) {
                    throw new Error('Failed to fetch user data');
                }
                return response.json();
            })
            .then(data => {
                const user = data.results[0];
                
                // Create user card with animation, website, and add the carousel functionality
                setTimeout(() => {
                    displayUser(user);
                    displayWeb(user);
                    displayArrowCarousel();
                    // displayDotCarousel();
                    
                    // Re-enable button
                    pullButton.disabled = false;
                    pullButton.textContent = 'Pull Random User!';
                }, 1000); // Delay to show animation
            })
            .catch(error => {
                console.error('Error fetching data:', error);
                
                // Show error message
                card.innerHTML = `
                    <div class="error-message">
                        Failed to fetch a random user. Please try again.
                    </div>
                `;
                
                // Re-enable button
                pullButton.disabled = false;
                pullButton.textContent = 'Pull Random User!';
            });
    }
    
    function displayUser(user) {
        // Create HTML for user information
        const userHTML = `
            <div class="user-info">
                <div class="avatar-container">
                    <div class="avatar-glow"></div>
                    <img class="avatar" src="${user.picture.large}" alt="User avatar">
                </div>
                
                <h2 class="user-name">${user.name.first} ${user.name.last}</h2>
                <p class="user-email">${user.email}</p>
                
                <div class="user-details">
                    <div class="detail-item">
                        <span class="detail-label">Age:</span> ${user.dob.age}
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Gender:</span> ${user.gender}
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Location:</span> ${user.location.city}, ${user.location.country}
                    </div>
                    <div class="detail-item">
                        <span class="detail-label">Phone:</span> ${user.phone}
                    </div>
                </div>
            </div>
        `;
        
        // Update card content
        card.innerHTML = userHTML;
        
        // Trigger animation after a short delay
        setTimeout(() => {
            document.querySelector('.user-info').classList.add('visible');
        }, 100);
    }

    function displayWeb(user) {
        // Create website after pull
        const webHTML = `
        <nav>
            <div class="nav">
                <a href="#HOME">HOME</a>
                <a href="#GAMES">GAMES</a>
                <a href="#ABOUT">ABOUT</a>
            </div>
            
            <div class="user">
                <img class="web-avatar" id="web-avatar" src="${user.picture.large}" onmouseover="displayData();" onclick="displayData();" alt="User avatar">
                <div class="data" id="data" onmouseleave="exit();">
                    <button class="exit" onclick="exit();">x</button>
                    <p class="web-data">Name: ${user.name.first} ${user.name.last}</p>
                    <p class="web-data">Email: ${user.email}</p>
                    <p class="web-data">Gender: ${user.gender}</p>
                    <p class="web-data">Phone: ${user.phone}</p>
                </div>
                <p class="greetings">Welcome, ${user.name.first}!</p>
            </div>
        </nav>

        <div class="main">
            <main id="HOME">
                <p>WELCOME TO GAMING HUB</p>
            </main>
        </div>

        <div class="contents">
            <div id="GAMES">
                <p>GAMES</p>
                <div class="apps">
                    <div class="game">
                        <div class="img">
                            <img src="./pics/ML.jpg" alt="Mobile Legends Icon">
                        </div>
                        <p>Mobile Legends</p>
                    </div>
                    <div class="game">
                        <div class="img">
                            <img src="./pics/COC.jpg" alt="Clash of Clans Icon">
                        </div>
                        <p>Clash of Clans</p>
                    </div>
                    <div class="game">
                        <div class="img">
                            <img src="./pics/COD.jpg" alt="Call of Duty Icon">
                        </div>
                        <p>Call of Duty</p>
                    </div>
                    <div class="game">
                        <div class="img">
                            <img src="./pics/SL.jpg" alt="Solo Leveling Icon">
                        </div>
                        <p>Solo Leveling</p>
                    </div>
                </div>
            </div>
            <div id="ABOUT">
                <p>ABOUT</p>
                <div>
                    <p>This is a gaming site.</p>
                </div>
            </div>
        </div>

        <div class="foot">
            <footer>
                <div class="footer">
                    <div>
                        <div class="socialIcons">
                            <a href="" target="_blank"><i class="fa-brands fa-facebook"></i></a>
                            <a href="" target="_blank"><i class="fa-brands fa-instagram"></i></a>
                            <a href="" target="_blank"><i class="fa-brands fa-twitter"></i></a>
                        </div>
                    </div>
                </div>
                <div class="footerBottom">
                    <p>
                        Copyright © 2025. All Rights Reserved.
                    </p>            
                </div>
            </footer>
        </div>
        `;

        // Update web content
        web.innerHTML = webHTML;
    }

    function displayArrowCarousel() {
        // Next and Previous Arrows
        const webHTML = `
                <a class="prev" onclick="plusSlides(-1)">❮ Previous</a>
                <a class="next" onclick="plusSlides(1)">Next ❯</a>
        `;

        // Update arrow carousel
        arr_carousel.innerHTML = webHTML;
    }

    function displayDotCarousel() {
        // Dot carousel functions
        const webHTML = `
                <span class="dot" onclick="currentSlide(1)"></span> 
                <span class="dot" onclick="currentSlide(2)"></span>
        `;

        // Update dot carousel
        dot_carousel.innerHTML = webHTML;
    }
    
    function addSparkles() {
        // Create sparkle elements
        const sparkleContainer = document.createElement('div');
        sparkleContainer.style.position = 'absolute';
        sparkleContainer.style.inset = '0';
        sparkleContainer.style.display = 'flex';
        sparkleContainer.style.alignItems = 'center';
        sparkleContainer.style.justifyContent = 'center';
        
        // Add different sparkles
        for (let i = 1; i <= 4; i++) {
            const sparkle = document.createElement('div');
            sparkle.classList.add('sparkle', `sparkle-${i}`);
            sparkleContainer.appendChild(sparkle);
        }
        
        // Add to card
        card.appendChild(sparkleContainer);
        
        // Remove sparkles after animation completes
        setTimeout(() => {
            if (sparkleContainer.parentNode === card) {
                card.removeChild(sparkleContainer);
            }
        }, 2000);
    }
});