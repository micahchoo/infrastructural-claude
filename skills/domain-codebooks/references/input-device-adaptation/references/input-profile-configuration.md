# Input Profile Configuration and Per-Device Shortcut Architecture

## The Problem

Different input devices (mouse, tablet, touchscreen, trackpad) need different shortcut mappings, gesture bindings, and interaction thresholds. A two-finger drag means "pan" on a touchscreen but "scroll" on a trackpad. A stylus barrel button might mean "right-click" for one user and "color picker" for another. Platform differences (macOS native gestures vs Linux/Android/Windows touch events) require different gesture vocabularies entirely. Without a structured configuration system, per-device behavior is hard-coded, user customization is impossible, and platform ports duplicate gesture logic.

Symptoms: users can't rebind touch gestures, tablet shortcuts conflict with keyboard shortcuts, platform-specific gestures break on other platforms, upgrading the app resets customized input profiles, adding a new input device requires touching every interaction handler.

## Competing Patterns

### Pattern A: Typed Shortcut Configuration with Device-Specific Enums

**When to use:** Professional applications supporting multiple input modalities (keyboard, mouse, tablet, touch, native gestures) where users need per-modality customization.

**When NOT to use:** Simple applications with fixed gesture mappings. Web applications where PointerEvent homogenizes input types.

**How it works:** Define a shortcut configuration type that encodes the input modality (key combo, mouse button, wheel, gesture, platform gesture) alongside the modality-specific parameters. Each action can have multiple shortcut configurations — one per supported input method. The configuration is serializable for persistence.

**Production example:** Krita `KisShortcutConfiguration` (`libs/ui/input/kis_shortcut_configuration.h`) uses enums to type shortcuts by input modality:

```cpp
enum ShortcutType {
    UnknownType,
    KeyCombinationType,   // A list of keys that should be pressed
    MouseButtonType,      // A mouse button, possibly with key modifiers
    MouseWheelType,       // Mouse wheel movement, possibly with key modifiers
    GestureType,          // A touch gesture
    MacOSGestureType,     // A macOS gesture
};
```

Gesture actions are platform-conditional:

```cpp
enum GestureAction {
    NoGesture,
#ifdef Q_OS_MACOS
    PinchGesture,       // Fingers moving towards/away from each other
    PanGesture,         // Fingers staying together but moving
    RotateGesture,      // Two fingers rotating around a pivot
    SmartZoomGesture,   // Double tap boolean zoom
#else
    OneFingerTap, TwoFingerTap, ThreeFingerTap, FourFingerTap, FiveFingerTap,
    OneFingerDrag, TwoFingerDrag, ThreeFingerDrag, FourFingerDrag, FiveFingerDrag,
    OneFingerHold,
#endif
    MaxGesture
};
```

Each configuration serializes to `{mode;type;[key,key];buttons;wheel;gesture}` with base-16 integers for compact storage. The `operator==` compares only input configuration, not the action it maps to — enabling detection of conflicts across profiles.

**Tradeoffs:** Platform `#ifdef` in the enum means gesture codes aren't portable across platforms. Adding a new platform (e.g., Wayland-specific gestures) requires extending the enum. The serialization format is compact but opaque — debugging requires a decoder.

### Pattern B: Parallel Shortcut Registries Per Device Class

**When to use:** Applications where stroke/drawing shortcuts, touch shortcuts, and native gesture shortcuts have fundamentally different matching semantics.

**When NOT to use:** Applications where all input types can be matched with the same algorithm.

**How it works:** Maintain separate shortcut registries (lists) per device class, each with its own matching algorithm. A central matcher (`KisShortcutMatcher`) holds all registries and dispatches incoming events to the appropriate one based on event type. Only one shortcut can be "running" at a time across all registries, preventing cross-device conflicts.

**Production example:** Krita `KisShortcutMatcher` (`libs/ui/input/kis_shortcut_matcher.h`) manages three parallel registries:

```cpp
class KisShortcutMatcher {
    // Three separate shortcut types with different matching semantics:
    void addShortcut(KisStrokeShortcut *shortcut);    // Mouse/tablet button + modifiers
    void addShortcut(KisTouchShortcut *shortcut);      // Touch point count + gesture type
    void addShortcut(KisNativeGestureShortcut *shortcut); // macOS native gestures

    // Separate event entry points per device class:
    bool buttonPressed(Qt::MouseButton button, QEvent *event);  // Mouse/tablet
    bool touchBeginEvent(QTouchEvent *event);                    // Touch
    bool nativeGestureBeginEvent(QNativeGestureEvent *event);    // Native gestures
};
```

Each registry uses different matching logic:
- **Stroke shortcuts** (`KisStrokeShortcut`): Match on modifier keys + mouse buttons, with Idle -> Ready -> Running state machine. Priority-based selection when multiple shortcuts match.
- **Touch shortcuts** (`KisTouchShortcut`): Match on touch point count (min/max) and gesture type (tap/drag/hold). Uses touch slop detection (`TOUCH_SLOP_SQUARED = 16 * 16`) to distinguish taps from drags. Buffers early events to wait for maximum touch point count before matching.
- **Native gesture shortcuts** (`KisNativeGestureShortcut`): Match on macOS-specific gesture types (pinch/pan/rotate/smart zoom).

Mutual exclusion: `KIS_SAFE_ASSERT_RECOVER_NOOP(!m_d->runningShortcut || !m_d->touchShortcut)` — a stroke shortcut and touch shortcut cannot run simultaneously.

**Tradeoffs:** Three matching algorithms to maintain. Cross-registry coordination is manual (assertions, not type-level guarantees). Adding a new device class (e.g., game controller) requires a new registry and entry points. The touch point buffering adds latency (waits for `numIterations = 10` events before committing to a match).

### Pattern C: Touch Gesture-to-Action Mapping Table

**When to use:** Applications that map touch gestures to discrete actions (undo, redo, tool switching) rather than continuous interactions (drawing, panning).

**When NOT to use:** Applications where gestures map to continuous interactions with position/velocity tracking.

**How it works:** Define a mapping table from gesture types (N-finger tap, N-finger drag, hold) to named application actions. Gestures trigger the action once on completion (not continuously during the gesture). Actions are looked up by name in the application's action registry.

**Production example:** Krita `KisTouchGestureAction` (`libs/ui/input/KisTouchGestureAction.cpp`) maps gestures to 15+ discrete actions:

```cpp
KisTouchGestureAction::KisTouchGestureAction()
    : KisAbstractInputAction("Touch Gestures")
{
    QHash<QString, int> shortcuts;
    shortcuts.insert(i18n("Undo"), UndoActionShortcut);
    shortcuts.insert(i18n("Redo"), RedoActionShortcut);
    shortcuts.insert(i18n("Toggle Canvas Only Mode"), ToggleCanvasOnlyShortcut);
    shortcuts.insert(i18n("Toggle Eraser"), ToggleEraserMode);
    shortcuts.insert(i18n("Color Sampler"), ColorSampler);
    shortcuts.insert(i18n("Activate Freehand Brush Tool"), FreehandBrush);
    shortcuts.insert(i18n("Activate Move Tool"), KisToolMove);
    shortcuts.insert(i18n("Activate Transform Tool"), KisToolTransform);
    // ... 15+ mappings
    setShortcutIndexes(shortcuts);
}

void KisTouchGestureAction::end(QEvent *event) {
    // Look up action name from shortcut index, trigger via KisKActionCollection
    KisKActionCollection *actionCollection =
        KisPart::instance()->currentMainwindow()->actionCollection();
    QAction *action = actionCollection->action(actionName);
    if (action) action->trigger();
}
```

The action is triggered in `end()`, not `begin()` — ensuring the gesture is complete before acting. This prevents undo on accidental touches.

**Tradeoffs:** Only works for discrete actions, not continuous gestures (panning, zooming are handled by different shortcut types). The action lookup by string name is fragile — typos fail silently. The mapping is populated at construction time and can't be changed without restarting the action.

## Decision Guide

- "Users need to customize per-device shortcuts?" -> Pattern A (typed configuration). Serialize input modality + parameters.
- "Mouse/tablet and touch need different matching logic?" -> Pattern B (parallel registries). Separate matching algorithms, single running constraint.
- "Touch gestures trigger discrete actions?" -> Pattern C (gesture-to-action mapping). Map to named actions, trigger on gesture completion.
- "Professional creative app?" -> All three: Pattern A for persistence, Pattern B for runtime matching, Pattern C for gesture-to-action mapping on top of B.
- "Simple web drawing app?" -> Skip this axis. Use pointer-event-normalization patterns instead. Configuration adds complexity that isn't justified without diverse device support.

## Anti-Patterns

### Don't: Hard-Code Gesture Meanings
**What happens:** Two-finger tap always means "undo" with no override. Users who prefer three-finger tap for undo (common on Android tablets) can't reconfigure. Power users leave for competing apps.
**Instead:** Use Pattern A — typed shortcut configurations that separate gesture detection from action mapping. Krita's profile system allows completely different gesture mappings per profile.

### Don't: Use a Single Matching Algorithm for All Input Types
**What happens:** Touch gestures forced through a keyboard-shortcut-style matcher (key + button combo) can't express "three-finger drag" or "touch hold." Mouse buttons forced through a gesture matcher add unnecessary latency.
**Instead:** Pattern B — separate registries with matching algorithms suited to each device class. Mouse shortcuts match on key + button state; touch shortcuts match on point count + motion type; native gestures match on OS gesture type.

### Don't: Skip Profile Migration on Version Upgrades
**What happens:** Users who customized their input profiles lose all configuration on upgrade. Or worse, old serialized shortcuts map to wrong actions because enum values shifted.
**Instead:** Krita's `KisInputProfileMigrator5To6` explicitly handles version transitions — it strips old touch shortcuts from user profiles, replaces them with the new default touch shortcuts, and preserves all other customizations. The migrator reads old-format profiles, filters by shortcut type, and appends new defaults:

```cpp
// KisInputProfileMigrator5To6::migrate()
QList<KisShortcutConfiguration> shortcuts = getShortcutsFromProfile(profile.fullpath);
// Remove old touch shortcuts
filterShortcuts(shortcuts, [](KisShortcutConfiguration shortcut) {
    return shortcut.type() != KisShortcutConfiguration::GestureType;
});
// Add new defaults
shortcuts.append(defaultTouchShortcuts());
```

### Don't: Ignore Platform-Specific Gesture APIs
**What happens:** Reimplementing pinch-zoom from raw touch events when the OS provides `QNativeGestureEvent` (macOS) leads to worse behavior — the OS gesture recognizer has access to hardware-level data (trackpad pressure, acceleration) that raw events don't expose. On Android, system-level three-finger gestures eat the events before the app sees them.
**Instead:** Krita's `MacOSGestureType` enum and `KisNativeGestureShortcut` handler use the OS gesture API when available. Platform-specific workarounds (`#ifdef Q_OS_ANDROID: bool ignoreCancel = d->lastPointCount > 2`) handle OS-level gesture conflicts.
