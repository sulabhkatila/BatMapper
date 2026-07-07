document.addEventListener("DOMContentLoaded", () => {
    // Intersection Observer for scroll animations
    const observerOptions = {
        root: null,
        rootMargin: "0px",
        threshold: 0.15,
    };

    const observer = new IntersectionObserver((entries, observer) => {
        entries.forEach((entry) => {
            if (entry.isIntersecting) {
                entry.target.classList.add("visible");
                // Optional: unobserve after animating once
                // observer.unobserve(entry.target);
            }
        });
    }, observerOptions);

    const animatedElements = document.querySelectorAll(".fade-in-up");
    animatedElements.forEach((el) => observer.observe(el));

    // Glow Orb mouse tracking effect
    const backgroundEffects = document.querySelector(".background-effects");
    if (backgroundEffects) {
        document.addEventListener("mousemove", (e) => {
            const x = e.clientX / window.innerWidth;
            const y = e.clientY / window.innerHeight;

            // Subtle parallax effect on orbs based on mouse position
            const orb1 = document.querySelector(".orb-1");
            const orb2 = document.querySelector(".orb-2");

            if (orb1 && orb2) {
                orb1.style.transform = `translate(${x * 20}px, ${y * 20}px)`;
                orb2.style.transform = `translate(${x * -30}px, ${y * -30}px)`;
            }
        });
    }

    // Header scroll effect
    const header = document.querySelector("header");
    window.addEventListener("scroll", () => {
        if (window.scrollY > 50) {
            header.style.background = "rgba(6, 11, 25, 0.9)";
            header.style.boxShadow = "0 4px 20px rgba(0, 0, 0, 0.3)";
        } else {
            header.style.background = "rgba(6, 11, 25, 0.7)";
            header.style.boxShadow = "none";
        }
    });

    // Set video playback rate to 1.25x
    const videos = document.querySelectorAll("video");
    videos.forEach((video) => {
        video.playbackRate = 2.5;
    });
});
