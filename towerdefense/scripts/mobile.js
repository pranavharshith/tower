// Mobile Support for Tower Defense Game
// Handles touch input and mobile UI updates

var isMobile = false;
var touchStartPos = { x: 0, y: 0 };
var longPressTimer = null;
var mobileUIUpdateInterval = null;
var isHandlingTouch = false;

// Detect if device is mobile
function detectMobile() {
    var userAgent = navigator.userAgent || navigator.vendor || window.opera;
    
    // Check for mobile user agents
    if (/android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent.toLowerCase())) {
        isMobile = true;
    }
    
    // Also check window width as fallback
    if (window.innerWidth <= 800) {
        isMobile = true;
    }
    
    return isMobile;
}

// Initialize mobile functionality when p5 is ready
function initMobileSupport() {
    if (!detectMobile()) return;
    
    // Prevent default touch behaviors only on the canvas
    var sketchHolder = document.getElementById('sketch-holder');
    if (sketchHolder) {
        sketchHolder.addEventListener('touchmove', function(e) {
            e.preventDefault();
        }, { passive: false });
        
        // Add touch event listeners
        sketchHolder.addEventListener('touchstart', handleTouchStart, false);
        sketchHolder.addEventListener('touchmove', handleTouchMove, false);
        sketchHolder.addEventListener('touchend', handleTouchEnd, false);
    }
    
    // Update mobile UI periodically
    mobileUIUpdateInterval = setInterval(updateMobileUI, 100);
    
    // Adjust canvas size for mobile
    setTimeout(function() {
        if (typeof resizeFit === 'function') {
            resizeFit();
        }
    }, 500);
}

// Touch event handlers
function handleTouchStart(e) {
    if (isHandlingTouch) return;
    
    var touch = e.touches[0];
    touchStartPos = { 
        x: touch.clientX, 
        y: touch.clientY,
        time: Date.now()
    };
    
    // Set up long press detection (0.5 seconds)
    longPressTimer = setTimeout(function() {
        // Long press could trigger a long press action if needed
    }, 500);
}

function handleTouchMove(e) {
    // Cancel long press if user moves finger
    if (longPressTimer) {
        clearTimeout(longPressTimer);
        longPressTimer = null;
    }
}

function handleTouchEnd(e) {
    // Cancel long press timer
    if (longPressTimer) {
        clearTimeout(longPressTimer);
        longPressTimer = null;
    }
    
    if (e.changedTouches.length === 0) return;
    
    var touch = e.changedTouches[0];
    var endPos = { x: touch.clientX, y: touch.clientY };
    var timeDiff = Date.now() - touchStartPos.time;
    
    // Check if it's a quick tap (not a long press or drag)
    var distX = Math.abs(endPos.x - touchStartPos.x);
    var distY = Math.abs(endPos.y - touchStartPos.y);
    var isQuickTap = timeDiff < 500 && distX < 10 && distY < 10;
    
    if (!isQuickTap) return;
    
    // Prevent multiple simultaneous touches
    if (isHandlingTouch) return;
    isHandlingTouch = true;
    
    try {
        // Convert touch position to canvas coordinates
        var canvas = document.querySelector('canvas');
        if (canvas) {
            var rect = canvas.getBoundingClientRect();
            
            // Check if touch is actually on the canvas
            if (touch.clientX < rect.left || touch.clientX > rect.right ||
                touch.clientY < rect.top || touch.clientY > rect.bottom) {
                return;
            }
            
            // Convert to canvas-relative coordinates
            mouseX = touch.clientX - rect.left;
            mouseY = touch.clientY - rect.top;
            
            // Call the mousePressed function from p5/sketch.js
            if (typeof mousePressed === 'function') {
                mousePressed();
            }
        }
    } finally {
        isHandlingTouch = false;
    }
}

// Update mobile UI with current game stats
function updateMobileUI() {
    if (!isMobile) return;
    
    try {
        // Update status display
        if (typeof wave !== 'undefined') {
            var waveEl = document.getElementById('mobile-wave');
            if (waveEl) waveEl.textContent = 'Wave: ' + wave;
        }
        if (typeof health !== 'undefined') {
            var healthEl = document.getElementById('mobile-health');
            if (healthEl) healthEl.textContent = 'Health: ' + health;
        }
        if (typeof cash !== 'undefined') {
            var cashEl = document.getElementById('mobile-cash');
            if (cashEl) cashEl.textContent = 'Cash: ' + cash;
        }
        if (typeof paused !== 'undefined') {
            var pauseBtn = document.getElementById('mobile-pause');
            if (pauseBtn) {
                pauseBtn.textContent = paused ? '⏸ Paused' : '▶ Playing';
            }
        }
        
        // Update tower info panel if a tower is selected
        if (typeof selected !== 'undefined' && selected) {
            updateMobileTowerInfo(selected);
        } else {
            var infoName = document.getElementById('mobile-info-name');
            var infoContent = document.getElementById('mobile-info-content');
            if (infoName) infoName.textContent = 'Tower Info';
            if (infoContent) infoContent.innerHTML = 'Tap on a tower to see details';
        }
    } catch (e) {
        // Silently handle errors during UI update
    }
}

// Update mobile tower information panel
function updateMobileTowerInfo(tower) {
    var nameEl = document.getElementById('mobile-info-name');
    var contentEl = document.getElementById('mobile-info-content');
    
    if (!contentEl || !nameEl) return;
    
    if (!tower || !tower.name) {
        nameEl.textContent = 'Tower Info';
        contentEl.innerHTML = 'Tap on a tower to see details';
        return;
    }
    
    nameEl.textContent = tower.name;
    
    var html = '';
    if (tower.cost) html += '<p>Cost: ' + tower.cost + '</p>';
    if (tower.damage) html += '<p>Damage: ' + tower.damage + '</p>';
    if (tower.range) html += '<p>Range: ' + tower.range + '</p>';
    if (tower.cooldown) html += '<p>Cooldown: ' + tower.cooldown + '</p>';
    if (tower.level) html += '<p>Level: ' + tower.level + '</p>';
    
    if (typeof cash !== 'undefined' && tower.cost) {
        var sellPrice = Math.floor(tower.cost * (typeof sellConst !== 'undefined' ? sellConst : 0.8) * (tower.level || 1));
        html += '<p>Sell Price: ' + sellPrice + '</p>';
        
        if (tower.upgrades && tower.upgrades.length > 0) {
            var upCost = tower.upgrades[0].cost;
            html += '<p>Upgrade Cost: ' + upCost + '</p>';
            html += '<button class="tower-btn" onclick="if (selected && selected.upgrades.length > 0) upgrade(selected.upgrades[0])">Upgrade</button>';
        }
        
        html += '<button id="sell-btn" class="tower-btn" style="background-color: rgb(248, 148, 6); color: #000; text-shadow: none;" onclick="if (selected) sell(selected)">Sell</button>';
    }
    
    contentEl.innerHTML = html;
}

// Helper function to cancel tower placement on mobile
function cancelPlace() {
    toPlace = false;
    if (typeof clearInfo === 'function') {
        clearInfo();
    }
    var infoContent = document.getElementById('mobile-info-content');
    if (infoContent) {
        infoContent.innerHTML = 'Tap on a tower to see details';
    }
}

// Initialize when document is ready
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function() {
        setTimeout(initMobileSupport, 100);
    });
} else {
    setTimeout(initMobileSupport, 100);
}

// Also initialize on window load to ensure p5 is ready
window.addEventListener('load', function() {
    setTimeout(initMobileSupport, 500);
});

// Handle window resize (orientation change)
window.addEventListener('resize', function() {
    if (typeof resizeFit === 'function') {
        setTimeout(function() {
            resizeFit();
        }, 100);
    }
});
