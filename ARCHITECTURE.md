# REDLINE Camera — Architecture

## Product principle
One cross-platform experience, native camera capture on each operating system, and a shared colour/imaging specification.

## Application layers

1. Presentation: Flutter UI, navigation, controls, preview framing.
2. Camera orchestration: capability discovery, camera selection, capture state, lifecycle.
3. Native capture adapters:
   - Android: Kotlin with Camera2 as the advanced capability source; CameraX may be used for lifecycle and compatibility helpers.
   - iOS: Swift with AVFoundation.
4. Imaging core: shared C++ core for deterministic colour transforms and tone mapping; platform GPU kernels for accelerated preview and processing.
5. Intelligence: on-device scene classification and exposure recommendations. It must be advisory and confidence-scored, not a black box that overrides user safety.
6. Storage: original capture, edited render, sidecar metadata, device profile.

## Important design decision
Do not force a single capture implementation onto both platforms. Android vendors expose different camera capabilities, and iOS devices expose a different set of controls. Each adapter reports capabilities in a common schema. The shared controller chooses only settings the current device actually supports.

## Capture pipeline

Preview:
Sensor/ISP preview -> native preview stream -> lightweight scene analysis -> exposure/white-balance recommendations -> preview display.

Still capture:
Native still capture -> preserve original JPEG/HEIF or DNG when available -> metadata capture -> optional REDLINE processing -> non-destructive save.

RAW:
DNG/RAW is optional and device-dependent. The app must never label a computational JPEG as RAW. Some phones produce better HDR results through their vendor ISP than through a single RAW exposure, so the app should compare supported paths rather than always preferring RAW.

## Colour pipeline
Use a colour-managed, scene-referred internal representation. ACEScg is a candidate working space for linear processing, but input transforms must be calibrated per camera/device. Implement a documented REDLINE transform rather than claiming exact RED IPP2 reproduction.

Suggested stages:
- input decoding and metadata interpretation
- black level / sensor correction where accessible
- demosaic only for actual RAW sensor data
- camera-to-working-space transform
- white balance and tint
- noise reduction
- exposure normalisation
- highlight reconstruction where possible
- tone mapping and gamut mapping
- creative look
- output encoding (sRGB, Display P3, or supported HDR)

## Automatic mode priorities
1. Prevent unrecoverable clipping in important highlights.
2. Maintain usable shutter speed for subject motion.
3. Avoid unnecessarily high ISO/noise.
4. Keep white balance stable during a shot.
5. Prefer natural colour over aggressive enhancement.
6. Use multi-frame HDR only when motion and device support make it safe.

## Device profile
Store:
- model identifier and OS version
- camera identifiers and lens roles
- supported output formats
- supported exposure/ISO/focus ranges
- RAW/HDR support
- calibration version
- measured versus inferred fields
- last calibration date

Do not infer sensor properties that the platform does not expose. Mark unknown values as unknown.

## Security and privacy
- Process locally by default.
- No account required for basic camera operation.
- No photo upload without explicit consent.
- Request only camera, microphone (for video with audio), and media permissions when needed.
- Keep diagnostic telemetry opt-in and avoid collecting image content.

## Milestones
M0: Flutter shell, live preview, still capture, local save.
M1: Capability discovery and common camera API.
M2: Exposure controls and robust automatic mode.
M3: Colour-managed still pipeline and device profiles.
M4: Video capture, HDR, and advanced monitoring.
M5: Calibration, performance tuning, and release hardening.
