// Swift HTTP Server Example JavaScript
console.log('Swift HTTP Server example website loaded successfully');

document.addEventListener('DOMContentLoaded', function() {
    console.log('DOM content loaded');
    
    // Add some interactive functionality
    const header = document.querySelector('header h1');
    if (header) {
        header.addEventListener('click', function() {
            console.log('Header clicked!');
            header.style.transform = header.style.transform === 'scale(1.1)' ? 'scale(1)' : 'scale(1.1)';
            header.style.transition = 'transform 0.3s ease';
        });
    }
    
    // Add click tracking for navigation
    const navLinks = document.querySelectorAll('nav a');
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            console.log('Navigation clicked:', this.href);
            
            // Add a small visual feedback
            this.style.transform = 'scale(0.95)';
            setTimeout(() => {
                this.style.transform = 'scale(1)';
            }, 150);
        });
    });
    
    // Log page info
    console.log('Page title:', document.title);
    console.log('Current URL:', window.location.href);
    console.log('User agent:', navigator.userAgent);
});

// Simple performance monitoring
window.addEventListener('load', function() {
    console.log('Page fully loaded');
    
    // Basic performance timing
    if (window.performance && window.performance.timing) {
        const timing = window.performance.timing;
        const loadTime = timing.loadEventEnd - timing.navigationStart;
        console.log('Page load time:', loadTime, 'ms');
    }
});

// Example function that could be called from other scripts
function greetUser(name = 'visitor') {
    console.log(`Hello, ${name}! Welcome to the Swift HTTP Server example.`);
    return `Hello, ${name}!`;
}

// Export for potential module usage
if (typeof module !== 'undefined' && module.exports) {
    module.exports = { greetUser };
}