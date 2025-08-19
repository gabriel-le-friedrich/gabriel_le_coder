// Modal functionality
const loginBtn = document.getElementById('loginBtn');
const heroLoginBtn = document.getElementById('heroLoginBtn');
const loginModal = document.getElementById('loginModal');
const closeModal = document.getElementById('closeModal');
const googleLoginBtn = document.getElementById('googleLogin');

function openModal() {
loginModal.classList.add('active');
document.body.style.overflow = 'hidden';
}

function closeModalFn() {
loginModal.classList.remove('active');
document.body.style.overflow = 'auto';
}

loginBtn.addEventListener('click', openModal);
heroLoginBtn.addEventListener('click', openModal);
closeModal.addEventListener('click', closeModalFn);

// Close modal when clicking outside
loginModal.addEventListener('click', function(e) {
if (e.target === loginModal) {
    closeModalFn();
}
});

// Google Login functionality
googleLoginBtn.addEventListener('click', function() {
// In a real implementation, this would redirect to Google OAuth
alert('This would connect to Google OAuth in a production environment');

// Simulate successful login
setTimeout(() => {
    closeModalFn();
    alert('Successfully logged in with Google!');
}, 1000);
});

// Form submission (just for demo)
const loginForm = document.querySelector('.login-form');
loginForm.addEventListener('submit', function(e) {
e.preventDefault();
alert('Login functionality would be implemented here in production');
closeModalFn();
});