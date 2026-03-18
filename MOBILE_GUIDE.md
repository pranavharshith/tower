# Mobile Tower Defense - User Guide

## Overview
The Tower Defense game now includes full mobile support! You can play the game on smartphones, tablets, and other mobile devices with touch controls and an optimized interface.

## Mobile Features

### Responsive Layout
- **Automatic Detection**: The game automatically detects if you're on a mobile device (based on screen width or user agent)
- **Desktop View**: On screens wider than 800px, you get the traditional desktop sidebar layout
- **Mobile View**: On smaller screens (phones and tablets), the interface switches to an optimized mobile layout

### Mobile Touch Controls
- **Tap to Play**: Simply tap anywhere on the game map to interact
  - Tap empty tiles to place towers
  - Tap towers to select them and view details
- **Mobile Control Panel**: At the bottom of the screen, you'll find:
  - **Status Display**: Current Wave, Health, and Cash amounts
  - **Play/Pause Button**: Start or pause the game
  - **Restart Button**: Reset the current game
  - **Tower Buttons**: 7 tower types available (Gun, Laser, Slow, Sniper, Rocket, Bomb, Tesla)
  - **Cancel Button**: Stop placing a tower without buying it
  - **Tower Info Panel**: Shows details about selected towers, including:
    - Tower name and cost
    - Damage, range, and cooldown values
    - Sell price
    - Upgrade options and cost

### Auto-Sizing
- The game canvas automatically adjusts its size based on your device's screen orientation and dimensions
- Supports both portrait and landscape orientations
- Handles device rotation smoothly

## How to Play on Mobile

1. **Starting the Game**
   - Open the game in your mobile browser
   - The game will automatically load in mobile mode
   - Press "Play" to begin the first wave

2. **Placing Towers**
   - Tap one of the tower buttons at the bottom (Gun, Laser, Slow, etc.)
   - Tap on an empty tile in the game map to place the tower
   - A range indicator will show while you're holding a tower to place
   - Tap "Cancel" if you change your mind

3. **Managing Towers**
   - Tap on any existing tower to select it
   - View its stats in the Tower Info panel at the bottom
   - Press "Upgrade" to upgrade the tower (if available)
   - Press "Sell" to sell the tower and get money back

4. **Game Controls**
   - Use "Play" button to pause/resume the game
   - Use "Restart" button to start a new game
   - Swipe up on the control panel to see more information

## Desktop vs Mobile

### Desktop Version (Screen width > 800px)
- Left sidebar with map import/export and store
- Right sidebar with status, map selection, and tower info
- Traditional mouse/keyboard controls
- Number keys (1-7) for quick tower selection
- Keyboard shortcuts available

### Mobile Version (Screen width ≤ 800px)
- Simplified full-screen game view
- Bottom control panel with all essential controls
- Touch-based interaction only
- Optimized button sizes for finger input
- Easy-to-read status information

## Tips for Mobile Play

1. **Screen Space**: The game dynamically scales to fit your screen. Try both portrait and landscape orientations to see which you prefer
2. **Tap Accuracy**: Towers are best placed by tapping on the center of the tile you want to target
3. **Control Panel**: The control panel scrolls if you need to access more options
4. **Auto-Save**: Your game state is maintained as you play (though specific save/load features may vary)

## Troubleshooting

**The game doesn't look right on mobile**
- Try refreshing the page
- Rotate your device to landscape mode (better for grid-based games)
- Check that you're using a modern browser (Chrome, Safari, Firefox, Edge)

**Touch controls don't work**
- Make sure you're tapping on the game canvas (the green-bordered area)
- Tap for quick actions, don't hold or drag
- Try refreshing the page

**Controls are too small**
- Rotate to landscape mode for larger buttons
- Pinching to zoom may help (depends on browser settings)

## Technical Details

- Built with **p5.js** for rendering and game logic
- Touch events are normalized to work with the p5.js mouse system
- Mobile detection is based on both user agent and screen width
- The interface automatically switches based on device capabilities

## Enjoy!

The mobile version brings the tower defense experience to your pocket. Have fun building and defending!
