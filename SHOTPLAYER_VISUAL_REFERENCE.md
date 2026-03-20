# ShotPlayerViewController - Visual Reference Guide

## Quick Layout Overview

### LANDSCAPE (iPad 11" & 13")
```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━━━┓
┃                                 ┃                ┃
┃   FRAME VIEW                    ┃  CONTROLS      ┃
┃   (70% of width)                ┃  PANEL         ┃
┃   16:9 aspect ratio             ┃  (30% width)   ┃
┃                                 ┃                ┃
┃  Top-left HUD chips:            ┃  Shot Name     ┃
┃  ┌─────────────────┐            ┃  Camera Name   ┃
┃  │ Shot 1          │            ┃                ┃
┃  │ Camera 1        │            ┃ [◄] [▶] [❚▶] ┃
┃  └─────────────────┘            ┃    (Centered)  ┃
┃  Top-right timecode:            ┃                ┃
┃  ┌──────────────┐               ┃                ┃
┃  │  00:15/02:00 │               ┃                ┃
┃  └──────────────┘               ┃                ┃
┃                                 ┃                ┃
┃  Center flash message           ┃                ┃
┃  (for shot transitions)         ┃                ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━━━┛

Width:
  iPad 11": Frame ≈ 640px | Controls ≈ 240px
  iPad 13": Frame ≈ 820px | Controls ≈ 280px

NOTE: No scrubber or film strip visible in landscape
      (Focus on preview, controls are on right)
```

---

### PORTRAIT (iPad 11" & 13")
```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃   FRAME VIEW                ┃
┃   (Full width, 65% height)  ┃
┃   16:9 aspect ratio         ┃
┃                             ┃
┃  ┌─────────────────┐        ┃
┃  │ Shot 1          │        ┃
┃  │ Camera 1        │        ┃
┃  └─────────────────┘        ┃
┃                             ┃
┃  Center cut flash           ┃
┃  (Shot 1 → Shot 2)          ┃
┃                             ┃
┃  ┌──────────────┐           ┃
┃  │  00:15/02:00 │           ┃
┃  └──────────────┘           ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ Shot 1  Camera 1            ┃  CONTROLS
┃ [◄] [▶] [❚▶] (Centered)   ┃  SECTION
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ 00:15  ━━●━━━━━━━  02:00    ┃  SCRUBBER
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃ SHOTS                       ┃  FILM STRIP
┃ [1][2][3][4][5][6][7]...   ┃  (Scrollable
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛   horizontally)

Heights (11"):
  Frame:       65% of screen
  Controls:    88px (fixed)
  Scrubber:    44px (fixed)
  Film Strip:  66px + padding

Heights (13"):
  Frame:       65% of screen
  Controls:    100px (fixed)
  Scrubber:    44px (fixed)
  Film Strip:  76px + padding
```

---

## Component Details

### FRAME VIEW (Top Priority)
```
┌──────────────────────────────────────────────────┐
│ ┌────────┐                        ┌──────────┐   │
│ │Shot 1  │                        │00:15/02:00      │
│ │Camera 1│                        └──────────┘   │
│ └────────┘                                      │
│                                                  │
│              (16:9 Video Frame)                  │
│              Displays camera POV                 │
│              during playback or                  │
│              scrubbing                          │
│                                                  │
│                  SHOT 1 → SHOT 2                │
│              (Cut flash message)                 │
│                                                  │
│                                                  │
│           Camera.aperture icon                   │
│              (when empty)                       │
│                                                  │
│         Loading spinner overlay                 │
│              (during capture)                   │
│                                                  │
└──────────────────────────────────────────────────┘

Features:
✓ contentMode = scaleAspectFit (maintains aspect)
✓ clipsToBounds (no content overflow)
✓ Placeholder icon when no image
✓ Loading spinner during capture
✓ HUD chips (shot, camera, time)
✓ Cut flash banner for transitions
```

---

### CONTROLS CONTAINER
```
┌───────────────────────────────────────┐
│  Shot 1                    Camera 1   │ ← Info labels
├───────────────────────────────────────┤
│                                       │
│        [◄]  [▶]  [❚▶]              │ ← Centered button stack
│       (Prev) (Next) (Play/Pause)    │
│                                       │
│  Spacing: 24pt between buttons        │
│  Button sizes vary by device:         │
│    11": 48px prev/next, 54px play    │
│    13": 54px prev/next, 60px play    │
└───────────────────────────────────────┘

Layout (Portrait):
    Left:    Shot name label
    Right:   Camera name label
    Bottom:  Button stack (centered)

Heights:
    11": 88px total
    13": 100px total

All buttons:
    - White tint color
    - Semi-transparent white background (9% opacity)
    - Circular shape (cornerRadius = height/2)
    - Touch feedback on tap
```

---

### SCRUBBER CONTAINER (Timeline)
```
┌────────────────────────────────────────────┐
│  00:15  ━━●━━━━━━━━━━━━  02:00            │
│  ^       ^                ^                 ^
│ Time    Fill              Track           Duration
│ Label   (Red,            (Gray)           Label
│         animated)        (4pt height)
│
│  Interactive slider thumb (white circle)
│  Overlaps track for easy dragging
└────────────────────────────────────────────┘

Components:
• currentTimeLabel    (Left, monospace)
• scrubberTrack       (Center, gray background)
• scrubberFill        (Center, red animated fill)
• scrubber            (Invisible slider, padding±10pt)
• durationLabel       (Right, monospace)

Track dimensions:
  Height: 4pt
  Radius: 2pt (rounded)
  Color: UIColor.white 12% opacity

Fill dimensions:
  Height: 4pt (same as track)
  Radius: 2pt (rounded)
  Color: #B12038 (red accent)
  Width: Animated based on progress

Time labels:
  Font: Monospace digit system font, 10pt
  Color: White 50% opacity
  Width: 42pt fixed

Fixed height: 44pt

Interaction:
  Dragging pauses playback
  Live frame capture as you scrub
  Releases to resume playback
```

---

### FILM STRIP CONTAINER (Shots List)
```
┌────────────────────────────────────────────────┐
│  SHOTS                                         │
├────────────────────────────────────────────────┤
│ [Shot 1] [Shot 2] [Shot 3] [Shot 4] ...       │
│   ✓        ✗        ✗        ✗                │
│  (Active) (Inactive) (Inactive)              │
│           (scroll →)                          │
└────────────────────────────────────────────────┘

Header:
  "SHOTS" label (9pt black, 20% opacity)
  Top padding: 8pt
  Left padding: 16pt

Cells:
  Background: Dark, with border when active
  Dimensions:
    11": 80px × 62px
    13": 90px × 70px
  
  Content:
    Thumbnail image (if available)
    OR shot number (if no thumbnail)
  
  Active indicator:
    Colored bottom bar (2.5pt height)
    Accent color matches shot
    Border: 1.5pt around cell

Spacing:
  Horizontal: 10pt between cells
  Vertical: Centered in container
  Padding: 16pt left/right on edges

Scrolling:
  Direction: Horizontal (left/right)
  Behavior: Programmatic (centers current shot)
  Indicator: Hidden

Interaction:
  Tap to select shot
  Auto-scrolls selected shot to center
  Pauses playback when tapped
```

---

## State Management Diagram

### Playback States
```
┌─────────────┐
│    IDLE     │ ← Initial state
└──────┬──────┘
       │ playBtn tapped
       ▼
┌─────────────┐
│   PLAYING   │ ◄─────────┐
└──────┬──────┘           │
       │                  │
       ├─ nextBtn ────────┼─────┐
       │                  │     │
       ├─ prevBtn ───────────────┼─────┐
       │                  │      │     │
       ├─ scrubberBegin  └─────────────┼──┐
       │                  │      │     │  │
       ├─ playBtn again ──┘      │     │  │
       │                        │     │  │
       └─ duration reached      │     │  │
              (playAll=false)   │     │  │
                   │            │     │  │
                   ▼            │     │  │
            ┌────────────┐      │     │  │
            │   STOPPED  │◄─────┘     │  │
            └────────────┘            │  │
                  ▲                   │  │
                  └───────────────────┘  │
                                         │
           nextBtn (at end) ────────┐    │
           or prevBtn (at start)    ▼    │
                            ┌──────────┐ │
                            │  SYNCING │ │
                            └──────────┘ │
                                  │      │
                                  └──────┘
                            (capture first frame)

Additional flags:
  • isScrubbing: Prevents playback updates during manual scrubbing
  • snapshotPending: Prevents multiple frame captures
  • isPlaying: Overall playback state
```

---

### Data Flow Diagram
```
USER INPUT
    │
    ├─► playBtn    ──► startPlayback() ──┐
    │                                     │
    ├─► nextBtn    ──► syncToCurrentShot()
    │                                     │
    ├─► prevBtn    ──► syncToCurrentShot()
    │                                     │
    ├─► scrubber   ──► scrubberValueChanged()
    │                                     │
    └─► filmStrip  ──► syncToCurrentShot()
                                         │
                                         ▼
                              updateScrubber()
                                    │
                                    ├─► Update scrubber.value
                                    │
                                    ├─► Update scrubberFill width
                                    │
                                    └─► updateTimeLabels()
                                               │
                                               ├─► currentTimeLabel
                                               ├─► durationLabel
                                               └─► hudTimeLbl
                                    │
                                    ├─► captureFrame(force: false)
                                    │        │
                                    │        └─► Rate-limited (30fps)
                                    │
CADisplayLink tick()
    │
    └─► currentTime calculation
         │
         ├─► updateScrubber()
         │
         ├─► Check if duration reached
         │
         └─► If playAll: nextShot()
```

---

## Constraint Hierarchy

### Shared Constraints (Always Active)
```
frameImageView
  ├─ Fill frameView completely
  └─ 16:9 aspect ratio maintained

frameView
  └─ Position (varies by orientation)

HUD Chips
  ├─ Fixed positions on frameView
  └─ Never change between orientations

Buttons
  ├─ Centered in btnStack
  ├─ Fixed sizes (resize for 11" vs 13")
  └─ Same for both orientations

scrubber Track & Slider
  ├─ Positioned between time labels
  └─ Same for both orientations
```

### Orientation-Specific Constraints

**LANDSCAPE ONLY:**
```
frameView
  ├─ Left: safeArea + 10pt
  ├─ Top: safeArea + 10pt
  ├─ Bottom: safeArea - 10pt
  ├─ Width = Height × 16/9
  └─ Right = controlsContainer left - 10pt

controlsContainer
  ├─ Right: safeArea
  ├─ Top: safeArea
  ├─ Bottom: safeArea
  └─ Width: 240pt (11") or 280pt (13")

scrubberContainer
  └─ Height: 0 (hidden)

filmStripContainer
  └─ Height: 0 (hidden)
```

**PORTRAIT ONLY:**
```
frameView
  ├─ Left: safeArea
  ├─ Right: safeArea
  ├─ Top: safeArea
  ├─ Height = Width × 9/16
  └─ Bottom = controlsContainer top

controlsContainer
  ├─ Top: frameView bottom
  ├─ Left: view left
  ├─ Right: view right
  └─ Height: 88pt (11") or 100pt (13")

scrubberContainer
  ├─ Top: controlsContainer bottom
  ├─ Left: view left
  ├─ Right: view right
  └─ Height: 44pt (fixed)

filmStripContainer
  ├─ Top: scrubberContainer bottom
  ├─ Left: view left
  ├─ Right: view right
  └─ Bottom: safeArea bottom
```

---

## Color Palette Reference

```
Primary Colors:
  Background:    #0B0B16 (RGB: 11,  11,  22)  - Dark, cinematic
  Controls BG:   #111130 (RGB: 17,  17,  48)  - Slightly lighter
  Thumb BG:      #0A0A14 (RGB: 10,  10,  20)  - Very dark
  Accent Red:    #B12038 (RGB: 177, 32,  56)  - Professional red

Secondary Colors (Shot Indicators):
  Red:     #B12038 (Primary accent)
  Blue:    #2E7CC6 (RGB: 46,  124, 198)
  Green:   #1FA673 (RGB: 31,  166, 115)
  Orange:  #B87A1F (RGB: 184, 122, 31)
  Purple:  #8C38BF (RGB: 140, 56,  191)
  
  → Cycles through shots (color[index % 5])

Opacity Variants (White):
  06%: UIColor.white.withAlphaComponent(0.06)   - Barely visible
  08%: UIColor.white.withAlphaComponent(0.08)   - Buttons bg
  09%: UIColor.white.withAlphaComponent(0.09)   - Buttons bg
  12%: UIColor.white.withAlphaComponent(0.12)   - Scrubber track
  20%: UIColor.white.withAlphaComponent(0.20)   - Labels
  40%: UIColor.white.withAlphaComponent(0.40)   - Secondary text
  50%: UIColor.white.withAlphaComponent(0.50)   - HUD backgrounds
  52%: UIColor.white.withAlphaComponent(0.52)   - HUD backgrounds
  70%: UIColor.white.withAlphaComponent(0.70)   - Secondary text
  80%: UIColor.white.withAlphaComponent(0.80)   - Flash message
```

---

## Responsive Typography

```
Shot Name Label:
  Font Size:   14pt semibold
  Color:       White (100%)
  Style:       Left-aligned

Camera Name Label:
  Font Size:   11pt regular
  Color:       White (50% opacity)
  Style:       Secondary info

Time Labels (Scrubber):
  Font:        Monospace digit system font
  Size:        10pt
  Color:       White (50% opacity)
  Alignment:   Centered
  Use:         Timecode display (MM:SS)

Film Strip Label:
  Font Size:   9pt black (ultra-heavy)
  Color:       White (20% opacity)
  Spacing:     1.5pt letter spacing
  Style:       "SHOTS" header

HUD Chips:
  Font Size:   10-11pt
  Colors:      Varied (see palette)
  Background:  Semi-transparent black
  Radius:      4pt rounded corners
  Padding:     Auto-sized around text

Cut Flash Banner:
  Font Size:   12pt semibold
  Color:       White (80% opacity)
  Background:  Black (60% opacity)
  Radius:      5pt rounded corners
  Animation:   Fade in 0.12s, fade out after 1.3s delay
```

---

## Quick Integration Checklist

- [ ] File created: `ShotPlayerViewController_Improved.swift`
- [ ] Contains `ShotPlayerViewController_Improved` class
- [ ] Public API matches original (same `init`, properties, methods)
- [ ] All UI elements properly initialized
- [ ] Constraints properly organized (shared + orientation-specific)
- [ ] Color palette applied consistently
- [ ] Film strip collection view registered with `StripCell`
- [ ] Display link for playback updates
- [ ] CADisplayLink selector calls `tick()` correctly
- [ ] Scrubber sync working (`isScrubbing` flag)
- [ ] Frame capture rate-limiting enabled
- [ ] HUD chips visible on frame
- [ ] Cut flash animation works
- [ ] Export functionality intact
- [ ] No constraint conflicts in console
- [ ] Layout adapts smoothly on rotation

---

**Ready to deploy!** 🚀
