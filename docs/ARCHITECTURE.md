# Architecture

## Boundaries

```text
Menu bar / hotkeys
        |
CaptureCoordinator
        |
ScreenCaptureKit snapshot
        |
Selection overlay ----> Annotation editor ----> Image exporter
        |
LongCaptureSession ----> ScrollStitcher ------> Image exporter
```

`CaptureCoordinator` admits only one active workflow at a time. Each asynchronous workflow carries a generation token, so a cancelled or delayed older task cannot dismiss a newer capture. One reserved Carbon hot key routes `Escape` to the active workflow without requiring Accessibility permission.

## UI split

- SwiftUI owns the menu-bar menu, settings, annotation toolbar, and long-capture controller.
- AppKit owns borderless overlay panels, pointer tracking, selection drawing, and the annotation canvas.
- The editor operates on immutable screenshot pixels plus a separate array of annotation elements. Export flattens them only at the final action.

## Capture

`ScreenCaptureService` uses `SCScreenshotManager`, `SCStream`, and `SCShareableContent`. A display is captured before the selection overlay appears, so the overlay cannot leak into the screenshot. Window capture uses a desktop-independent `SCContentFilter` when possible.

## Coordinate systems

- AppKit screen/view coordinates use a lower-left origin.
- ScreenCaptureKit window frames and `CGImage` pixels use a top-left-oriented display space.
- Conversion is isolated in display snapshots and crop helpers. Annotation geometry remains in canvas points and is scaled only during export.

## Long screenshots

The long-capture session rounds the selected viewport to whole display points once, then keeps one ScreenCaptureKit stream alive for the entire session. `sourceRect`, native-pixel `width`/`height`, a 30 fps minimum interval, and a three-frame queue remain fixed, so the first and subsequent frames cannot diverge through different crop or Retina-rounding paths. The session keeps at most ten pending frames and compacts a backlog before it can increase latency or memory without bound. Incomplete stream frames and this app's own panels are excluded.

Accepted frames are registered as they arrive rather than deferred to a final all-or-nothing pass. Vision estimates vertical translation across five horizontal comparison bands; agreement between bands filters out sticky headers and animated regions. A high-confidence full-frame estimate and the original grayscale overlap search are retained as fallbacks. Near-identical or unreliable frames are skipped, and the accepted overlap values make final rendering deterministic.

During capture, four click-through mask panels surround—but never overlap—the selected viewport, leaving the underlying application directly scrollable and making guide leakage physically impossible. A separate borderless, click-through panel shows accepted image segments beside the viewport only when enough external screen space exists; it is never placed over the capture source. Status and cancel/finish controls live in a small nonactivating floating bar.

The stream filter is rebuilt from fresh `SCShareableContent` after the capture UI is visible, so every current app window is excluded. Native display scale, best capture resolution, an exact non-scaling output size, complete-frame validation, and a short UI-settling delay protect first-frame sharpness. Cursor capture is disabled for scrolling sessions to avoid transient matching artifacts.

Only the previous full frame and the already accepted non-overlapping image segments are retained. This bounds working memory close to the final image size instead of growing by one full Retina viewport per sample. Tiny movements accumulate before acceptance, reducing redundant seams and registration work. The workflow-level Carbon hot key keeps unmodified `Escape` available globally without requesting Accessibility permission.

Final rendering validates both image height and a 60-million-pixel memory budget before allocating the output canvas. This keeps the accepted RGBA strips plus the final RGBA canvas near a 512 MiB upper bound before encoder overhead. Low-information frames and inconsistent stream dimensions are skipped rather than resampled or accepted as uncertain seams; an in-flight alignment is allowed to finish before the final image is rendered.

Overlap search uses a coarse pass followed by exact local refinement. It preserves row-level accuracy while reducing repeated pixel comparisons during rapid scrolling.

The workflow expects manual downward scrolling inside a stable viewport. Video, large horizontal motion, or scrolling farther than the remaining overlap in one step may reduce match quality; the live status asks the user to slow down instead of accepting a bad seam.

## Privacy and permissions

- No network dependency is used by the app.
- Screenshot pixels live in memory until the user explicitly copies or saves.
- Screen Recording permission is requested only when capture begins.
- The app does not require Accessibility permission for the initial manual-scroll design.

## Rollback

Source changes are reverted through Git. The app stores only preferences in `UserDefaults`; uninstalling or rolling back the binary does not affect user screenshots.
