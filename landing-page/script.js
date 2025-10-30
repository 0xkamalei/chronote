// Time Vibe Landing Page JavaScript

// Google Form link placeholder
// Please replace the link below with your actual Google Form link
const GOOGLE_FORM_LINK = 'https://docs.google.com/forms/d/e/1FAIpQLScVcoC-ASVexoQ9JanyCbJ3OYCMkpkqycdCasaV8PP4iGJYbA/viewform?usp=dialog';

// Wait for DOM to load
document.addEventListener('DOMContentLoaded', function() {
    // Get all join waitlist buttons
    const joinButtons = document.querySelectorAll('#joinWaitlistBtn, #heroJoinBtn, #ctaJoinBtn');
    
    // Add click event listener to each button
    joinButtons.forEach(button => {
        button.addEventListener('click', function() {
            // Open Google Form in new tab
            window.open(GOOGLE_FORM_LINK, '_blank');
        });
    });
    
    // Mobile menu functionality
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const nav = document.querySelector('.nav');
    
    if (mobileMenuBtn && nav) {
        mobileMenuBtn.addEventListener('click', function() {
            nav.style.display = nav.style.display === 'flex' ? 'none' : 'flex';
        });
    }
    
    // Smooth scrolling functionality
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
        anchor.addEventListener('click', function (e) {
            e.preventDefault();
            
            const targetId = this.getAttribute('href');
            const targetElement = document.querySelector(targetId);
            
            if (targetElement) {
                window.scrollTo({
                    top: targetElement.offsetTop - 80,
                    behavior: 'smooth'
                });
                
                // Close menu on mobile when navigation link is clicked
                if (window.innerWidth <= 768 && nav) {
                    nav.style.display = 'none';
                }
            }
        });
    });
});

// Handle navigation menu display/hide on window resize
window.addEventListener('resize', function() {
    const nav = document.querySelector('.nav');
    
    if (window.innerWidth > 768 && nav) {
        nav.style.display = 'flex';
    } else if (nav) {
        nav.style.display = 'none';
    }
});

// Add simple animation effects
function animateOnScroll() {
    const elements = document.querySelectorAll('.feature-card, .screenshot-item');
    
    elements.forEach(element => {
        const elementPosition = element.getBoundingClientRect().top;
        const windowHeight = window.innerHeight;
        
        if (elementPosition < windowHeight - 100) {
            element.style.opacity = '1';
            element.style.transform = 'translateY(0)';
        }
    });
}

// Initial setup for animated elements
window.addEventListener('load', function() {
    // Setup feature cards animation
    const featureCards = document.querySelectorAll('.feature-card');
    
    featureCards.forEach((card, index) => {
        card.style.opacity = '0';
        card.style.transform = 'translateY(20px)';
        card.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
        card.style.transitionDelay = `${index * 0.1}s`;
    });
    
    // Setup screenshot items animation
    const screenshotItems = document.querySelectorAll('.screenshot-item');
    
    screenshotItems.forEach((item, index) => {
        item.style.opacity = '0';
        item.style.transform = 'translateY(20px)';
        item.style.transition = 'opacity 0.5s ease, transform 0.5s ease';
        item.style.transitionDelay = `${index * 0.1}s`;
    });
    
    animateOnScroll();
});

// Trigger animation on scroll
window.addEventListener('scroll', animateOnScroll);