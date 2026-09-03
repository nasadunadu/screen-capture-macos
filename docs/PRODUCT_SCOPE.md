# Product Scope: Screenshot MVP

## Goal

Replace the owner's daily iShot screenshot workflow with a private, native macOS app focused on two jobs: ordinary screenshots and scrolling long screenshots.

## Success criteria

1. A user can start region, window, or full-screen capture from the menu bar or a global shortcut.
2. Region capture provides crosshair selection, live dimensions, and cancellation.
3. The captured image can be annotated without opening a separate document editor.
4. Annotation includes shapes, lines/arrows, pen, text, and spotlight.
5. The user can copy, save, or Save As in PNG/JPEG.
6. A selected scrollable area can collect multiple stable frames while the user scrolls and produce one stitched image.
7. Pixels remain local and permission failures produce clear recovery guidance.

## Included

- Region, window, full screen, previous area, preset area, and delayed full screen
- Cursor inclusion preference
- Inline annotation and non-destructive undo/redo
- PNG/JPEG quality and destination settings
- Optional rounded corners and drop shadow
- Long capture with manual scrolling, frame feedback, and overlap matching
- Standalone Dock app, menu-bar companion, launch-at-login preference, and editable global shortcuts

## Explicitly excluded

- Screen recording
- Audio recording
- Screenshot translation
- OCR
- Cloud upload or account system
- Automatic web-page DOM extraction

## Long-capture interaction

1. Select a vertically scrollable viewport.
2. Enter long-capture mode from the selection toolbar or menu command.
3. Scroll normally. The app samples the selected viewport and records changed frames.
4. A compact controller displays captured-frame count and recent thumbnails.
5. Finish to stitch and export, or cancel without writing files.

The first release deliberately uses manual scrolling. This works across browsers, chat apps, documents, and native scroll views without app-specific plugins or Accessibility automation.
