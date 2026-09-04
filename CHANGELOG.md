# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

No user-visible changes yet.

## [0.4.11] - 2026-09-04

### Fixed

- Rebuilt annotation presentation around one retained root view and window. The selection overlay and post-capture editor now keep the canvas and toolbar in one stable z-order tree, so drawing an arrow, shape, or line cannot hide the toolbar.
- Removed the previous two-panel toolbar lifecycle and stopped reordering toolbar subviews during mouse events.
- Removed AppKit cursor-rect mutations from the selection overlay. On macOS 26, `resetCursorRects()` could raise an Objective-C exception during a resize or first annotation stroke and terminate the app with `SIGABRT`.
- Removed cursor-rect invalidation calls from the drag lifecycle so selection updates no longer race the AppKit display-cycle tracker.

## [0.4.10] - 2026-09-03

### Fixed

- Kept the selection-stage annotation toolbar inside the screenshot overlay so it remains visible after drawing an arrow, rectangle, line, or other annotation.
- Removed the separate toolbar-window z-order race that could hide the toolbar when the annotation canvas became key.
- Preserved toolbar positioning when the selection is adjusted or moved.

## [0.4.9] - 2026-09-03

### Fixed

- Kept the selection-stage annotation toolbar above the canvas after the first arrow, rectangle, line, or other drawing gesture.
- Added the current app version and build number to the Settings window.
- Added regression coverage for the selection-stage toolbar interaction callback.

## [0.4.8] - 2026-09-03

### Fixed

- Kept the annotation toolbar persistently above the canvas while drawing rectangles, arrows, lines, and other tools.
- Added a regression test covering toolbar z-order, child-window ownership, and deactivate behavior.

## [0.4.7] - 2026-09-03

### Added

- Initial native macOS project and first screenshot MVP scope.
- Standalone Dock app dashboard for direct functional testing.
- Editable global shortcuts with `Command-4` and `Command-5` defaults.
- Larger annotation toolbar with symmetric cancel/confirm actions anchored at the right edge.
- One-click long-capture action beside cancel/confirm, with a larger low-chrome preview and faster frame sampling.
- Custom blue click-hand app icon with reduced outer whitespace for better Dock visibility.
- Permission-denied recovery now opens the Screen Recording privacy pane and refreshes automatically on return.
- Dock icon is explicitly loaded at launch to prevent the generic placeholder from appearing after local updates.
- Screen-capture authorization now uses real ScreenCaptureKit access as the final check, relaunches once after stale permission changes, and uses stable development signing.
- Retina-native capture dimensions and direct high-resolution region sampling for crisp screenshots and faster long capture.
- Table-based shortcut preferences with click-to-record fields for every screenshot mode.
- Rounded macOS app-icon tile with transparent corners and a matching in-app brand mark.
- Rebuilt scrolling capture around one fixed native-pixel ScreenCaptureKit stream, eliminating first-frame Retina rounding mismatches.
- Added live Vision translation registration with five-band consensus, high-confidence and grayscale fallbacks, and deterministic final stitching.
- Corrected long-capture preview aspect ratios and now skips incomplete or unreliable frames instead of failing the entire result.
- Replaced the framed long-capture controller with an iShot-style split workspace: a click-through live viewport on the left, seamless stitched-content preview on the right, and a compact floating action bar.
- Prevented self-capture feedback and blue guide leakage by rebuilding the ScreenCaptureKit exclusion filter and moving all guide pixels outside the source rectangle.
- Improved first-frame sharpness with native display scale, best-resolution non-scaling capture, complete-frame validation, hidden cursor, and a short UI-settling delay.
- Reduced long-session memory use to the previous viewport plus accepted output segments, accumulated tiny scroll movements, and raised the safe frame limit.
- Added global `Escape` cancellation throughout long capture and final rendering without requiring Accessibility permission.
- Changed launch behavior to a silent menu-bar utility: no dashboard window, no Dock activation, and no foreground interruption until the user chooses an action.
- Restored regular Dock presence and the branded app icon while retaining silent, windowless launch.
- Made the menu-bar Settings action explicitly activate the app and open the native Settings scene.
- Added a clearly labeled annotation color palette with custom colors, selected-element recoloring, and undo support.
- Replaced the unlabeled line-width slider with a labeled numeric control that edits selected annotations and groups each drag into one undo step.
- Rebuilt arrows as a single filled tapered shape with a fine tail, widening shaft, and proportionally larger arrowhead.
- Kept the area outside the selected screenshot dimmed throughout annotation so the final capture boundary stays visually unambiguous.
- Rebuilt the annotation bar as a single-row, icon-only iShot-style control strip without OCR; repeated tool clicks reveal color and line-width options in a compact popover.
- Moved annotation color into one persistent global color control and removed the toolbar delete button while keeping keyboard deletion available.
- Removed the sequence-number and mosaic tools from both the visible toolbar and numeric tool shortcuts.
- Added a post-drag selection adjustment stage with four iShot-style corner rulers, invisible edge resize targets, interior movement, a live size/shadow control, and an immediately available action toolbar.
- Doubled the selection corner-ruler stroke and separated it from the selection border by 2 pt for clearer visual targeting.
- Changed the selection border and corner rulers to the fixed `#8839EF` purple accent.
- Activated the arrow tool as soon as the first region selection finishes, allowing the first drag inside the crop to draw immediately without another toolbar click.
- Added a privacy manifest declaring local-only preferences and no collected data.
- Added deterministic export-plan, long-capture pipeline, sticky-header, memory-budget, and alignment performance coverage.
- Added a direct-distribution release checklist for compatibility, Developer ID signing, notarization, Gatekeeper, GitHub, and rollback gates.

### Fixed

- Prevented stack-overflow crashes when dragging the corner-radius, JPEG-quality, delay, or preset-size controls by removing recursive property observers and validating through explicit setters.
- Delivered the first canvas drag immediately after choosing a toolbar tool instead of consuming it only to reactivate the canvas panel.
- Prevented overlapping screenshot workflows and stale asynchronous tasks from dismissing a newer capture.
- Extended global `Escape` cancellation across preparation, selection, annotation, and scrolling capture without being removed by shortcut updates.
- Serialized ScreenCaptureKit stream state to eliminate cross-thread access races under strict concurrency checking.
- Preserved an in-flight final scrolling frame when the user finishes immediately after scrolling.
- Rejected mismatched and low-information scrolling frames instead of resampling or accepting arbitrary seams.
- Added height and total-pixel safety limits before allocating a long-image canvas.
- Sanitized corrupted numeric preferences and invalid crop geometry before use.
- Committed active text edits before export and wired Return/Escape in the annotation canvas.
- Prevented an AppKit `addCursorRect` exception when a resize target touches a screen edge by clipping every cursor region to the overlay bounds.
- Removed duplicate image processing and clipboard writes from save-and-copy export, and moved image effects, encoding, and disk writes off the main thread.
- Bounded scrolling capture to a low-latency 30 fps stream, three-frame ScreenCaptureKit queue, ten pending analysis frames, and a 60-million-pixel output budget.
- Reduced overlap-search work with coarse scanning plus exact local refinement while retaining fast-scroll and sticky-header alignment accuracy.

### Changed

- Switched the Xcode project from one fixed signing-certificate hash to automatic signing for clone portability.
- Enabled complete Swift concurrency checking and removed the unused legacy dashboard view.
- Compacted the annotation toolbar and aligned its cancel/confirm end to the selected region's lower-right edge.
- Removed the sequence and mosaic implementations, stale settings copy, and unused Core Image rendering rather than leaving hidden dead code.
- Disabled code-coverage instrumentation in Release builds and enabled scheme-level analysis without building the test bundle in Release mode.
