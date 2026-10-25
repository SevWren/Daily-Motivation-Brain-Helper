# Video Speed Controller — Complete Codebase Analysis

---

## 1. Extension Architecture Overview

### Manifest V3 Structure

The extension is declared in `manifest.json` at version `0.9.1`, targeting Manifest V3 (`manifest_version: 3`) with a minimum Chrome version of 89 [`manifest.json:1-7`].

**Permissions declared** [`manifest.json:14-18`]:
- `storage` — for reading and writing user settings via `chrome.storage.sync`
- `activeTab` — for querying the active tab from the popup
- `tabs` — for tab lifecycle events (navigation, removal, activation) in the service worker

**Service worker** [`manifest.json:19-21`]:
- `src/background.js` is registered as the Manifest V3 service worker. It handles icon management and controller lifecycle tracking.

**Options page** [`manifest.json:22-25`]:
- `src/ui/options/options.html`, opened in a new tab (`open_in_tab: true`).

**Popup action** [`manifest.json:26-33`]:
- Default popup is `src/ui/popup/popup.html`.
- Default icons use 19px and 38px variants.

**Content scripts** [`manifest.json:34-53`]:
- `src/content/injector.js` is the sole directly-injected content script.
- Matches `http://*/*`, `https://*/*`, and `file:///*`, with `all_frames: true` and `match_about_blank: true`.
- Explicitly excludes `https://hangouts.google.com/*` and `https://meet.google.com/*`.
- Injects `src/styles/inject.css` as a content-script stylesheet.

**Web-accessible resources** [`manifest.json:55-73`]:
- The following paths are exposed to pages (required because the main extension code runs in the page's JavaScript context, not the isolated content-script world):
  - `src/styles/inject.css`, `src/styles/shadow.css`
  - `src/module-loader.js`
  - `src/core/*.js`, `src/utils/*.js`, `src/ui/*.js`, `src/observers/*.js`, `src/site-handlers/*.js`, `src/content/*.js`

### Isolated-World Workaround

Chrome MV3 content scripts run in an isolated JavaScript world. They cannot share scope with page scripts. The `injector.js` content script injects all extension modules as `<script>` tags into the page's own document, placing all code in the host page's world. This is documented in `docs/ai_generated/adr/0001-window-vsc-global-namespace.md`.

### Global Namespace

All modules register their exports on `window.VSC`. Because scripts can be injected more than once (e.g., iframe scenarios), every module guards against double-loading with an `if (!window.VSC.ClassName)` check [`src/core/settings.js:9`] [`src/core/storage-manager.js:9`] [`src/utils/logger.js:9`] [`src/utils/constants.js:12`].

---

## 2. Entry Points & Boot Sequence

### Step 1 — Content Script Injection (`injector.js`)

When a page loads, Chrome injects `src/content/injector.js` into the content-script isolated world. The script checks `document.readyState` and defers actual module injection:

- `loading` → waits for `DOMContentLoaded`, then calls `requestIdleCallback(injectModules, { timeout: 3000 })` [`src/content/injector.js:264-274`]
- `interactive` → calls `requestIdleCallback(injectModules, { timeout: 2000 })` [`src/content/injector.js:275-281`]
- `complete` → calls `requestIdleCallback(injectModules, { timeout: 1000 })` [`src/content/injector.js:282-289`]

### Step 2 — Module Injection (`injectModules`)

`injectModules()` in `injector.js` sequentially appends `<script>` tags to the document for each module, in this exact order [`src/content/injector.js:37-60`]:

1. `src/utils/constants.js`
2. `src/utils/logger.js`
3. `src/utils/debug-helper.js`
4. `src/utils/dom-utils.js`
5. `src/utils/event-manager.js`
6. `src/core/storage-manager.js`
7. `src/core/settings.js`
8. `src/observers/media-observer.js`
9. `src/observers/mutation-observer.js`
10. `src/core/action-handler.js`
11. `src/core/video-controller.js`
12. `src/ui/controls.js`
13. `src/ui/drag-handler.js`
14. `src/ui/shadow-dom.js`
15. `src/site-handlers/base-handler.js`
16. `src/site-handlers/netflix-handler.js`
17. `src/site-handlers/youtube-handler.js`
18. `src/site-handlers/facebook-handler.js`
19. `src/site-handlers/amazon-handler.js`
20. `src/site-handlers/apple-handler.js`
21. `src/site-handlers/index.js`
22. `src/content/inject.js`

Every 5 modules, control is yielded via `requestIdleCallback` or a 5ms `setTimeout` [`src/content/injector.js:68-76`].

After module injection, `injectSiteSpecificScripts()` is called — currently only Netflix triggers an additional script: `src/site-handlers/scripts/netflix.js` is injected if `location.hostname === 'www.netflix.com'` [`src/content/injector.js:90-106`].

Then `setupMessageBridge()` is called, which also immediately calls `injectUserSettings()` [`src/content/injector.js:122`].

### Step 3 — CSS Injection

`injectCSS()` is called before any module scripts, appending a `<link>` element for `src/styles/inject.css` into `document.head` [`src/content/injector.js:23-29`].

### Step 4 — Settings Injection

`injectUserSettings()` reads all Chrome storage keys via `chrome.storage.sync.get(null, ...)` and dispatches a `VSC_USER_SETTINGS` CustomEvent on `window` with the storage contents as `detail` [`src/content/injector.js:243-261`]. This event is received by `StorageManager._setupSettingsListener()` in the page context, which caches the settings in `StorageManager._injectedSettings` [`src/core/storage-manager.js:15-23`].

### Step 5 — Extension Initialization (`inject.js`)

`src/content/inject.js` defines the `VideoSpeedExtension` class and immediately instantiates and calls `extension.initialize()` at the bottom of the file [`src/content/inject.js:395-406`].

`initialize()` does [`src/content/inject.js:19-77`]:
1. Grabs references to all global `window.VSC.*` classes.
2. Calls `this.config.load()` — loads settings from storage.
3. Checks `config.settings.enabled`; exits if false.
4. Checks `isBlacklisted(config.settings.blacklist)`; exits if blacklisted.
5. Calls `this.siteHandlerManager.initialize(document)` — detects and initializes the site handler.
6. Calls `this.addDomainClass()` — adds `vsc-domain-{hostname}` to `document.body` for CSS targeting.
7. Creates `EventManager` and `ActionHandler` instances with a circular reference between them.
8. Calls `this.setupObservers()` — creates `MediaElementObserver` and `VideoMutationObserver`.
9. Calls `this.initializeWhenReady(document, ...)` — waits for `document.readyState === 'complete'`, then calls `initializeDocument(doc)`.

### Step 6 — Document Initialization

`initializeDocument(document)` [`src/content/inject.js:83-110`]:
1. Guards against double-init by checking/setting `document.body.classList.contains('vsc-initialized')`.
2. Calls `this.eventManager.setupEventListeners(document)` — attaches `keydown` and `ratechange` listeners.
3. If in a sub-document (iframe), calls `setupDocumentCSS(document)` to inject `inject.css`.
4. Calls `this.deferExpensiveOperations(document)`.

### Step 7 — Deferred Media Scanning

`deferExpensiveOperations(document)` defers via `requestIdleCallback` (timeout 2000ms) [`src/content/inject.js:116-140`]:
1. Starts the `VideoMutationObserver` on the document.
2. Calls `deferredMediaScan(document)`.

`deferredMediaScan` uses another `requestIdleCallback` (timeout 3000ms) to call `mediaObserver.scanForMediaLight(document)` (no shadow DOM traversal). If that finds no media, `scheduleComprehensiveScan(document)` is scheduled with a 1-second `setTimeout`, which calls `mediaObserver.scanAll(document)` [`src/content/inject.js:146-202`].

For each media element found, `onVideoFound(media, parent)` is called, which creates a `new VideoController(video, parent, config, actionHandler, shouldStartHidden)` and assigns it to `video.vsc` [`src/content/inject.js:243-275`].

### Step 8 — Background Service Worker

The background script (`src/background.js`) starts via `chrome.runtime.onInstalled` or `chrome.runtime.onStartup`. It maintains a `Map<tabId, Set<controllerId>>` called `tabControllers` and handles icon state. It responds to messages `VSC_CONTROLLER_CREATED`, `VSC_CONTROLLER_REMOVED`, and `VSC_QUERY_ACTIVE_CONTROLLERS` from content scripts [`src/background.js:60-103`].

---

## 3. Feature Map

### 3.1 Playback Speed — Increase (`faster` action)

**What it does**: Adds the binding's `value` (default 0.1) to the current `video.playbackRate`, clamped to `SPEED_LIMITS.MAX` (16.0).

**Upstream**:
- Keyboard shortcut: `keydown` event on the document (captured phase) matches a binding with `action === 'faster'` in `EventManager.handleKeydown` [`src/utils/event-manager.js:156-269`].
- UI button: Click on the `+` button (`data-action="faster"`) inside the shadow DOM, handled by `ControlsManager.setupButtonHandlers` [`src/ui/controls.js:51-74`].

**Downstream**:
1. `EventManager.handleKeydown` → `ActionHandler.runAction('faster', value, event)` [`src/utils/event-manager.js:242`].
2. `ActionHandler.runAction` iterates `config.getMediaElements()`, shows the controller, and calls `ActionHandler.executeAction('faster', value, video, e)` for non-cancelled media elements [`src/core/action-handler.js:114-158`].
3. `executeAction` computes `fasterSpeed = min((playbackRate < 0.1 ? 0.0 : playbackRate) + value, 16)` and calls `this.setSpeed(video, fasterSpeed)` [`src/core/action-handler.js:183-191`].
4. `setSpeed` sets `video.playbackRate = numericSpeed` (or dispatches a `ratechange` event if `forceLastSavedSpeed` is set), updates `speedIndicator.textContent`, updates `config.settings.lastSpeed`, optionally stores per-video speed in `config.settings.speeds`, calls `config.save(...)`, and calls `eventManager.refreshCoolDown()` [`src/core/action-handler.js:310-358`].

**Files involved**:
- `src/utils/event-manager.js:156-269` (keydown handler)
- `src/ui/controls.js:51-74` (button click handler)
- `src/core/action-handler.js:93-191`, `310-358` (runAction, executeAction, setSpeed)
- `src/core/settings.js:74-88` (config.save)
- `src/core/storage-manager.js:89-115` (StorageManager.set)

**Data flow**: `keydown` event keyCode → matched `keyBinding.value` → `setSpeed(video, newRate)` → `video.playbackRate` (DOM property) + `speedIndicator.textContent` update + `chrome.storage.sync.set` (via VSC_SAVE_SETTINGS event).

---

### 3.2 Playback Speed — Decrease (`slower` action)

**What it does**: Subtracts the binding's `value` from `video.playbackRate`, clamped to `SPEED_LIMITS.MIN` (0.07).

**Upstream**: Same as `faster` — keyboard shortcut (default `Z`, keyCode 90) or `−` button click.

**Downstream**: `executeAction('slower', value, video, e)` computes `slowerSpeed = max(playbackRate - value, 0.07)` and calls `setSpeed` [`src/core/action-handler.js:193-200`]. All downstream steps identical to `faster`.

---

### 3.3 Playback Speed — Set Exact (`SET_SPEED` action / popup)

**What it does**: Sets `video.playbackRate` to an exact numeric value.

**Upstream**:
- Popup: User clicks a preset button (`data-speed`) or one of the fine-control buttons (`#speed-decrease`, `#speed-increase`, `#speed-reset`) in `popup.html`/`popup.js` [`src/ui/popup/popup.js:128-151`].
- Popup `setSpeed(speed)` calls `chrome.tabs.sendMessage(tabs[0].id, { type: 'VSC_SET_SPEED', payload: { speed } })` [`src/ui/popup/popup.js:153-162`].
- `VSC_MESSAGE` bridge: `injector.js` receives the chrome runtime message and dispatches a `VSC_MESSAGE` CustomEvent on `window` [`src/content/injector.js:159-172`].
- `inject.js` listens for `VSC_MESSAGE`, handles `VSC_SET_SPEED`, calls `actionHandler.setSpeed(video, targetSpeed)` for each video [`src/content/inject.js:348-358`].
- Direct `executeAction` path: `action === 'SET_SPEED'` calls `setSpeed(video, speed)` [`src/core/action-handler.js:267-280`].

**Downstream**: Same as `faster` — `setSpeed` sets `video.playbackRate`, updates speed indicator, saves to storage.

**Data flow**: Popup button click → `chrome.tabs.sendMessage` → content script `chrome.runtime.onMessage` → `window.dispatchEvent(VSC_MESSAGE)` → `inject.js` VSC_MESSAGE handler → `actionHandler.setSpeed` → `video.playbackRate`.

---

### 3.4 Playback Speed — Reset (`reset` action)

**What it does**: Implements a toggle. If current playback rate equals the target, it toggles between 1.0x and the `fast` binding value. If not, it stores the current rate as the new `reset` binding value and sets speed to the target.

**Upstream**: Keyboard shortcut (default `S`, keyCode 83) or the reset button in the popup.

**Downstream**: `ActionHandler.resetSpeed(video, target)` [`src/core/action-handler.js:389-408`]:
- If `video.playbackRate === target`:
  - If also equals the current `reset` binding value: toggles to 1.0 or `fast` speed.
  - Otherwise: sets speed to `reset` binding value.
- If `video.playbackRate !== target`: stores `video.playbackRate` into the `reset` binding, then calls `setSpeed(video, target)`.

---

### 3.5 Playback Speed — Preferred Speed (`fast` action)

**What it does**: Calls `resetSpeed(video, value)` where `value` is the `fast` binding's value (default 0.1, effectively toggling to a "fast" speed). The action name and default value in `DEFAULT_SETTINGS` suggest this is a user-configured preferred speed toggle.

**Upstream**: Keyboard shortcut (default `X`, keyCode 88) or via popup reset button logic [`src/ui/popup/popup.js:80-93`].

**Downstream**: `executeAction('fast', value, video, e)` calls `this.resetSpeed(video, value)` [`src/core/action-handler.js:239-241`].

---

### 3.6 Keyboard Shortcut Handling

**What it does**: Listens for `keydown` events at the document capture phase, matches them against stored `keyBindings`, and dispatches the corresponding action.

**Upstream**: Browser `keydown` event on the document (or `window.top.document` when in an iframe) [`src/utils/event-manager.js:124-148`].

**Downstream** (`EventManager.handleKeydown`) [`src/utils/event-manager.js:156-270`]:
1. Deduplicates events using `lastKeyEventSignature` (keyCode + timestamp + type).
2. Skips if any modifier key (Alt, Control, Fn, Meta, Hyper, OS) is active via `getModifierState`.
3. Skips if `event.target` is `INPUT`, `TEXTAREA`, or `isContentEditable`.
4. Skips if `config.getMediaElements()` is empty.
5. Finds matching binding via `config.settings.keyBindings.find(item => item.key === keyCode)`.
6. Calls `actionHandler.runAction(binding.action, binding.value, event)`.
7. If `binding.force === true`, calls `event.preventDefault()` and `event.stopPropagation()` to block the host page's key handler.

**Keybinding diagnostic instrumentation**: For key codes 82 (R) and 84 (T), or key values `'R'` and `'T'`, detailed diagnostic logs are written to `window.VSC.keyBindingDiagnostics` (a capped array of 50 entries) and a `VSC_KEYBINDING_DIAGNOSTIC` CustomEvent is dispatched on `window`. The same check runs in `injector.js`'s own `keydown` handler in the content-script world [`src/content/injector.js:123-156`].

**Default key bindings** (from `DEFAULT_SETTINGS`) [`src/utils/constants.js:40-52`]:
| Action | Key (code) | Value |
|--------|-----------|-------|
| slower | Z (90) | 0.1 |
| faster | C (67) | 0.1 |
| fast | X (88) | 0.1 |
| rewind | E (69) | 30 |
| rewind | W (87) | 120 |
| advance | R (82) | 30 |
| advance | T (84) | 120 |
| reset | S (83) | 1.0 |
| display | V (86) | 0 |
| mark | M (77) | 0 |
| jump | J (74) | 0 |

**Files involved**: `src/utils/event-manager.js:115-270`, `src/utils/constants.js:40-52`, `src/core/action-handler.js:93-161`.

---

### 3.7 UI Controller Rendering

**What it does**: Creates a floating speed-controller widget overlaid on each media element, containing a draggable speed indicator and five buttons (rewind «, decrease −, increase +, advance », hide ×).

**Upstream**: `VideoController` constructor is called from `VideoSpeedExtension.onVideoFound` [`src/content/inject.js:264-270`] after a media element is discovered.

**Downstream** (`VideoController` constructor) [`src/core/video-controller.js:9-51`]:
1. Creates a `ControlsManager` instance.
2. Calls `config.addMediaElement(target)`.
3. Calls `this.initializeSpeed()` — sets initial `video.playbackRate`.
4. Calls `this.initializeControls()` — builds the DOM wrapper and shadow DOM.
5. Calls `this.setupEventHandlers()` — attaches `play` and `seeked` listeners on the video.
6. Calls `this.setupMutationObserver()` — watches `src`/`currentSrc` attribute changes.
7. Assigns `target.vsc = this`.
8. Dispatches `VSC_CONTROLLER_CREATED` CustomEvent on `window`.

**`initializeControls()`** [`src/core/video-controller.js:104-185`]:
1. Calls `ShadowDOMManager.calculatePosition(video)` — computes `top`/`left` relative to `offsetParent` [`src/ui/shadow-dom.js:226-237`].
2. Creates a `<div class="vsc-controller">` wrapper with CSS classes: `vsc-nosource` if no video source and `readyState < 2`, `vsc-hidden` if `config.settings.startHidden` or `shouldStartHidden` is true.
3. Inline CSS is applied for `position: absolute`, `z-index: 9999999`, and explicit hide styles if hidden.
4. Calls `ShadowDOMManager.createShadowDOM(wrapper, { top, left, speed, opacity, buttonSize })`.
5. Calls `controlsManager.setupControlEvents(shadow, video)`.
6. Stores `speedIndicator` reference.
7. Calls `insertIntoDOM(document, wrapper)` — inserts via site-handler positioning rules.

**Shadow DOM construction** (`ShadowDOMManager.createShadowDOM`) [`src/ui/shadow-dom.js:15-171`]:
- Calls `wrapper.attachShadow({ mode: 'open' })`.
- Creates a `<style>` element with embedded CSS (identical to `shadow.css`).
- Creates `#controller` div with `top`, `left`, `opacity` inline styles.
- Creates `.draggable` span with `data-action="drag"` and the initial speed text.
- Creates `#controls` span with five buttons: `«` (rewind), `−` (slower), `+` (faster), `»` (advance), `×` (display).
- All buttons have `data-action` attributes matching action names.

**CSS classes on the wrapper** (in `inject.css`) [`src/styles/inject.css`]:
- `.vsc-nosource`: `display: none !important` — hides when no video source.
- `.vsc-hidden`: `display: none !important; visibility: hidden !important; opacity: 0 !important` — hides the controller.
- `.vsc-manual:not(.vsc-hidden)`: forces visible when manually shown.
- `.vsc-controller`: default `visibility: visible; display: block`.
- `.vsc-show`: used by `showController` to temporarily reveal the controller; combined with CSS transitions (e.g., `.ytp-autohide .vsc-show` makes it visible on YouTube).

**Files involved**: `src/core/video-controller.js:104-185`, `src/ui/shadow-dom.js:15-237`, `src/ui/controls.js:19-125`, `src/styles/inject.css`, `src/styles/shadow.css`.

---

### 3.8 Controller Visibility — Show/Hide (`display` action)

**What it does**: Toggles the `vsc-hidden` class on the controller wrapper. Adds `vsc-manual` to mark user intent. Clears inline fallback styles to avoid CSS conflicts.

**Upstream**:
- Keyboard shortcut (default `V`, keyCode 86).
- UI button: `×` button (`data-action="display"`) in the shadow DOM.
- Popup: `TOGGLE_DISPLAY` message type handled in `inject.js` as `actionHandler.runAction('display', null, null)` [`src/content/inject.js:386-389`].

**Downstream** (`executeAction('display', ...)`) [`src/core/action-handler.js:208-228`]:
1. Adds `vsc-manual` to `controller.classList`.
2. Toggles `vsc-hidden` on `controller.classList`.
3. Removes inline `display`, `visibility`, `opacity` properties from `controller.style`.

**Files involved**: `src/core/action-handler.js:208-228`, `src/styles/inject.css:5-14`.

---

### 3.9 Controller Drag

**What it does**: Allows repositioning the controller overlay by clicking and dragging the speed indicator.

**Upstream**: `mousedown` on the `.draggable` span (the speed indicator). Handled by `ControlsManager.setupDragHandler` which calls `actionHandler.runAction('drag', false, e)` [`src/ui/controls.js:31-43`].

**Downstream** (`executeAction('drag', ...)`) [`src/core/action-handler.js:235-237`] → `DragHandler.handleDrag(video, e)` [`src/ui/drag-handler.js:14-55`]:
1. Gets the `#controller` element inside the shadow root.
2. Calls `DomUtils.findVideoParent(controller)` to find the nearest parent with the same dimensions.
3. Adds `vcs-dragging` class to `video` and `dragging` class to `#controller`.
4. Records initial mouse position and controller position.
5. Attaches `mousemove`, `mouseup`, and `mouseleave` listeners on the parent element.
6. `startDragging`: updates `shadowController.style.left` and `.style.top` with delta from initial position.
7. `stopDragging`: removes all three listeners and removes the dragging classes.

**Files involved**: `src/ui/controls.js:31-43`, `src/core/action-handler.js:235-237`, `src/ui/drag-handler.js:14-55`, `src/utils/dom-utils.js:120-132`.

---

### 3.10 Mouse Wheel Speed Control

**What it does**: Scrolling the mouse wheel over the `#controller` element inside the shadow root changes the playback speed in 0.1 increments/decrements.

**Upstream**: `wheel` event on the `#controller` element inside the shadow DOM, registered in `ControlsManager.setupWheelHandler` [`src/ui/controls.js:83-112`].

**Downstream**:
1. `event.preventDefault()` stops page scrolling.
2. Computes `delta = Math.sign(event.deltaY)` — negative delta (scroll up) increases speed, positive decreases.
3. Computes `newSpeed = clamp(video.playbackRate ± 0.1, MIN, MAX)`.
4. Sets `video.playbackRate = newSpeed` directly (bypasses `ActionHandler.setSpeed`, so no storage save).
5. Updates `.draggable` text content to the new speed.

Note: The wheel handler sets `video.playbackRate` directly without going through `setSpeed`, so speed is not persisted to storage from this path.

**Files involved**: `src/ui/controls.js:83-112`.

---

### 3.11 Blink (Momentary Show, `blink` action)

**What it does**: Temporarily reveals a hidden controller for 1 second (default), then hides it again.

**Upstream**: Called from `EventManager.updateSpeedFromEvent` whenever a `ratechange` event is observed that isn't filtered by the cooldown [`src/utils/event-manager.js:388`]. Also triggered by `executeAction('blink', ...)` path.

**Downstream** (`ActionHandler.blinkController(controller, duration)`) [`src/core/action-handler.js:461-483`]:
1. Clears any existing blink timeout.
2. Removes `vsc-hidden`.
3. For non-audio controllers: sets a `setTimeout` to re-add `vsc-hidden` after `duration` ms (default 1000ms).
4. For audio controllers (detected via `isAudioController`): keeps the controller visible (no re-hide timeout).

**Files involved**: `src/core/action-handler.js:461-500`, `src/utils/event-manager.js:386-389`.

---

### 3.12 Show Controller Temporarily (`showController`)

**What it does**: Adds the `vsc-show` class to a controller for 2 seconds, then removes it. Respects `startHidden` setting — only shows if `startHidden` is false or the controller has been manually toggled.

**Upstream**: Called from `ActionHandler.runAction` for every action processed on a media element [`src/core/action-handler.js:140`].

**Downstream** [`src/utils/event-manager.js:412-436`]:
1. If `config.settings.startHidden` and no `vsc-manual` class: skips.
2. Adds `vsc-show` to `controller.classList`.
3. Clears any existing timer.
4. Sets a `setTimeout` for 2000ms to remove `vsc-show`.

**Files involved**: `src/utils/event-manager.js:412-436`.

---

### 3.13 Seek Rewind/Advance (`rewind`/`advance` actions)

**What it does**: Moves `video.currentTime` backward or forward by the specified number of seconds.

**Upstream**: Keyboard shortcut (rewind: E=30s, W=120s; advance: R=30s, T=120s by default) or `«`/`»` buttons.

**Downstream** (`executeAction` → `this.seek(video, seekSeconds)`) [`src/core/action-handler.js:363-368`]:
- Delegates to `window.VSC.siteHandlerManager.handleSeek(video, seekSeconds)`.
- Base handler: `video.currentTime = clamp(currentTime + seekSeconds, 0, duration)` [`src/site-handlers/base-handler.js:41-51`].
- Netflix handler: sends `window.postMessage({ action: 'videospeed-seek', seekMs: seekSeconds * 1000 }, 'https://www.netflix.com')` instead, using the Netflix JavaScript API through the `netflix.js` page-context script [`src/site-handlers/netflix-handler.js:38-57`].

---

### 3.14 Pause/Play Toggle (`pause` action)

**What it does**: If `video.paused`, calls `video.play()`; otherwise calls `video.pause()`.

**Upstream**: Keyboard shortcut (no default; user must assign one in options). Also reachable via `executeAction('pause', ...)`.

**Downstream**: `ActionHandler.pause(video)` [`src/core/action-handler.js:374-382`] directly calls `video.play()` or `video.pause()`.

---

### 3.15 Mute Toggle (`muted` action)

**What it does**: Toggles `video.muted`.

**Upstream**: Keyboard shortcut (no default) or `executeAction('muted', ...)`.

**Downstream**: `ActionHandler.muted(video)` sets `video.muted = !video.muted` [`src/core/action-handler.js:414-416`].

---

### 3.16 Volume Up/Down (`louder`/`softer` actions)

**What it does**: Increases or decreases `video.volume` by the binding's value, clamped to [0, 1].

**Upstream**: Keyboard shortcut (no default). Accessible via options page as custom shortcuts.

**Downstream**: `ActionHandler.volumeUp(video, value)` → `video.volume = min(1, (volume + value).toFixed(2))` [`src/core/action-handler.js:423-425`]. `ActionHandler.volumeDown(video, value)` → `video.volume = max(0, (volume - value).toFixed(2))` [`src/core/action-handler.js:432-434`].

---

### 3.17 Mark and Jump (`mark`/`jump` actions)

**What it does**: `mark` stores the current `video.currentTime` on `video.vsc.mark`. `jump` sets `video.currentTime = video.vsc.mark` if a mark exists.

**Upstream**: Keyboard shortcuts (mark: M=77, jump: J=74) by default.

**Downstream**: `ActionHandler.setMark(video)` sets `video.vsc.mark = video.currentTime` [`src/core/action-handler.js:440-443`]. `ActionHandler.jumpToMark(video)` sets `video.currentTime = video.vsc.mark` if it exists [`src/core/action-handler.js:449-454`].

---

### 3.18 Rate Change Interception

**What it does**: Listens for `ratechange` events on the document (capture phase). Used for two purposes: (1) enforcing `forceLastSavedSpeed`, and (2) keeping the speed indicator and storage in sync when the page changes the playback rate externally.

**Upstream**: `ratechange` DOM event fired on any media element, captured at document level by `EventManager.setupRateChangeListener` [`src/utils/event-manager.js:306-319`].

**Downstream** (`EventManager.handleRateChange(event)`) [`src/utils/event-manager.js:326-347`]:
1. If cooldown is active: calls `event.stopImmediatePropagation()` to block the event from reaching the page.
2. Gets the actual video via `event.composedPath()[0]` (handles shadow DOM).
3. If `forceLastSavedSpeed` enabled:
   - If event has `detail.origin === 'videoSpeed'`: sets `video.playbackRate = event.detail.speed`.
   - Otherwise: overrides `video.playbackRate = config.settings.lastSpeed`.
   - Calls `event.stopImmediatePropagation()`.
4. Calls `updateSpeedFromEvent(video)`.
5. `updateSpeedFromEvent` updates `speedIndicator.textContent`, `config.settings.speeds[src]`, `config.settings.lastSpeed`, calls `chrome.storage.sync.set({ lastSpeed: speed })` directly if Chrome APIs are available, and calls `actionHandler.runAction('blink', null, null)`.

**Files involved**: `src/utils/event-manager.js:306-389`.

---

### 3.19 Speed Initialization on `play` and `seeked` Events

**What it does**: When a media element fires `play` or `seeked`, re-applies the correct stored speed. This prevents sites from resetting playback rate on video resume or chapter change.

**Upstream**: `play` and `seeked` events on `video`, registered in `VideoController.setupEventHandlers` [`src/core/video-controller.js:228-253`].

**Downstream** (`mediaEventAction`):
1. Looks up `config.settings.speeds[event.target.currentSrc]`.
2. If `rememberSpeed` disabled: uses `storedSpeed = 1.0`; sets `reset` binding to `fast` binding value.
3. If `rememberSpeed` enabled: uses `config.settings.lastSpeed`.
4. Calls `actionHandler.setSpeed(event.target, storedSpeed)`.

---

### 3.20 Source Change Detection

**What it does**: Watches the `src` and `currentSrc` attributes of the video element. When the source is removed, adds `vsc-nosource` (hides the controller). When restored, removes `vsc-nosource`.

**Upstream**: `MutationObserver` on the video element itself, set up in `VideoController.setupMutationObserver` [`src/core/video-controller.js:259-280`].

**Downstream**: Adds or removes `vsc-nosource` class on `this.div` (the controller wrapper).

---

### 3.21 Settings Persistence — Read

**What it does**: Loads all settings from `chrome.storage.sync` (or from the injected-settings cache in page context).

**Upstream**: Called from `VideoSpeedExtension.initialize()` via `config.load()` [`src/content/inject.js:37`]; also from options page `restore_options()` [`src/ui/options/options.js:356-467`].

**Downstream** (`VideoSpeedConfig.load()`) [`src/core/settings.js:20-67`]:
1. Detects context: if `chrome.storage` is available, uses `StorageManager.get(DEFAULT_SETTINGS)` (direct Chrome API); otherwise uses `StorageManager.waitForInjectedSettings(DEFAULT_SETTINGS)` which polls every 10ms for `_injectedSettings` to be populated.
2. Processes `keyBindings`: uses storage bindings or defaults if empty; saves defaults if none are stored.
3. Casts each setting to its correct type (Number, Boolean, String).
4. Calls `ensureDisplayBinding(storage)` to backfill the `display` binding if missing (upgrade path).
5. Calls `window.VSC.logger.setVerbosity(settings.logLevel)`.

**Files involved**: `src/core/settings.js:20-67`, `src/core/storage-manager.js:29-53`, `src/core/storage-manager.js:60-82`.

---

### 3.22 Settings Persistence — Write

**What it does**: Saves settings to `chrome.storage.sync` (or dispatches a `VSC_SAVE_SETTINGS` event in page context for the content script to save).

**Upstream**:
- `ActionHandler.setSpeed` calls `config.save({ lastSpeed, speeds })` on every speed change [`src/core/action-handler.js:350-353`].
- `EventManager.updateSpeedFromEvent` calls `chrome.storage.sync.set({ lastSpeed: speed })` directly [`src/utils/event-manager.js:378-385`].
- Options page `save_options()` calls `config.save(settingsToSave)` [`src/ui/options/options.js:262-353`].
- `VideoSpeedConfig.load()` calls `save()` on first initialization (to persist defaults).

**Downstream** (`VideoSpeedConfig.save(newSettings)`) [`src/core/settings.js:74-88`]:
1. Merges `newSettings` into `this.settings`.
2. Calls `StorageManager.set(this.settings)`.
3. `StorageManager.set`: if Chrome APIs available, calls `chrome.storage.sync.set(data, callback)`; otherwise dispatches `VSC_SAVE_SETTINGS` CustomEvent on `window` with `detail = data`.
4. The `injector.js` `VSC_SAVE_SETTINGS` listener receives this event and calls `chrome.storage.sync.set(event.detail)` [`src/content/injector.js:175-197`].

**Files involved**: `src/core/settings.js:74-88`, `src/core/storage-manager.js:89-115`, `src/content/injector.js:175-197`.

---

### 3.23 Settings — Default Values

Defined in `src/utils/constants.js:28-60` as `DEFAULT_SETTINGS`:
- `lastSpeed: 1.0` — last playback rate
- `enabled: true` — extension on/off
- `speeds: {}` — per-URL speed map
- `displayKeyCode: 86` — legacy display key (V)
- `rememberSpeed: false` — whether to restore per-video speed
- `forceLastSavedSpeed: false` — override site speed resets
- `audioBoolean: true` — enable audio element controllers
- `startHidden: false` — hide controller by default
- `controllerOpacity: 0.3` — controller opacity
- `controllerButtonSize: 14` — button font size
- `keyBindings: [...]` — 11 default bindings (see §3.6)
- `blacklist: "www.instagram.com\nimgur.com\nteams.microsoft.com\nmeet.google.com"` — default blacklisted sites
- `logLevel: 3` (WARNING)

---

### 3.24 Options Page

**What it does**: Provides a full-page UI (opened in a new tab) for configuring all extension settings, including keyboard shortcuts, blacklist, and advanced options.

**Upstream**: User navigates to options via:
- Clicking the settings button in the popup (`#config`) → `window.open(chrome.runtime.getURL("src/ui/options/options.html"))` [`src/ui/popup/popup.js:14-16`].
- Chrome's extensions settings page.

**Options page HTML** loads scripts in this order [`src/ui/options/options.html:7-11`]:
1. `../../utils/constants.js`
2. `../../utils/logger.js`
3. `../../core/storage-manager.js`
4. `../../core/settings.js`
5. `options.js`

Note: The options page runs in an extension page context, so Chrome APIs are available directly.

**Key functions in `options.js`**:
- `restore_options()` [`src/ui/options/options.js:356-467`]: Loads settings via `VideoSpeedConfig.load()`, populates all form fields.
- `save_options()` [`src/ui/options/options.js:262-353`]: Reads all form fields, removes legacy storage keys, calls `videoSpeedConfig.save(settingsToSave)`, then reloads and validates.
- `restore_defaults()` [`src/ui/options/options.js:469-507`]: Calls `videoSpeedConfig.save(DEFAULT_SETTINGS)`, removes custom shortcuts from UI, reloads.
- `add_shortcut()` [`src/ui/options/options.js:158-198`]: Inserts a new custom shortcut row in the `#customs` section.
- `show_experimental()` [`src/ui/options/options.js:509-569`]: Reveals "advanced features" rows and adds `customForce` select elements to all shortcut rows.
- `recordKeyPress(e)` [`src/ui/options/options.js:92-124`]: Captures key codes for shortcut inputs. Backspace clears the input; Escape sets `"null"`; blacklisted keys (Tab, Shift, Ctrl, Alt, Meta) are blocked; other keys are displayed using `keyCodeAliases` or `String.fromCharCode`.
- `validate()` [`src/ui/options/options.js:218-259`]: Validates blacklist regex patterns.

**Shortcut row structure**: Each `.row.customs` has `.customDo` (action select), `.customKey` (key input), `.customValue` (value input), and optionally `.customForce` (force/propagation select) when experimental features are enabled.

**Files involved**: `src/ui/options/options.html`, `src/ui/options/options.js`.

---

### 3.25 Popup

**What it does**: A 280px-wide Material Design popup that shows speed controls (decrease, reset, increase), speed presets (0.5x–2.5x), a power toggle button, and a settings button.

**Upstream**: User clicks the extension icon in Chrome's toolbar.

**Key behaviors** [`src/ui/popup/popup.js`]:
- `loadSettingsAndInitialize()`: Reads `keyBindings` from `chrome.storage.sync`, extracts `slowerStep`, `fasterStep`, and `resetSpeed` values from bindings, updates button labels and `data-delta` attributes.
- Decrease/increase buttons call `adjustSpeed(delta)` → `chrome.tabs.sendMessage(tabId, { type: 'VSC_ADJUST_SPEED', payload: { delta } })`.
- Reset button calls `setSpeed(preferredSpeed)` → `chrome.tabs.sendMessage(tabId, { type: 'VSC_SET_SPEED', payload: { speed } })`.
- Preset buttons call `setSpeed(speed)` directly.
- Power button (`#disable`) reads `enabled` from storage, toggles it via `chrome.storage.sync.set({ enabled })`, updates icon state, and shows a "reload page" status message.
- Settings button opens the options page in a new tab.

**Icon management**: `toggleEnabledUI(enabled)` calls `chrome.action.setIcon(...)` directly from the popup context, using the `_disabled` or regular icon variants [`src/ui/popup/popup.js:50-57`].

**Files involved**: `src/ui/popup/popup.html`, `src/ui/popup/popup.js`, `src/ui/popup/popup.css`.

---

### 3.26 Extension Enable/Disable

**What it does**: A global on/off switch. When disabled, `inject.js` exits early before creating any controllers or observers.

**Upstream**: Power button in popup writes `{ enabled: false }` to `chrome.storage.sync` [`src/ui/popup/popup.js:30-40`].

**Downstream**: On the next page load, `VideoSpeedExtension.initialize()` calls `config.load()`, reads `settings.enabled`, and returns early with `"Extension is disabled"` log if false [`src/content/inject.js:40-43`].

Note: Disabling does not remove existing controllers from already-loaded pages; a page reload is required.

---

### 3.27 Blacklist

**What it does**: Per-site exclusion list. If the current page URL matches any entry, the extension exits without attaching any controllers.

**Upstream**: Blacklist is stored in `config.settings.blacklist` (newline-separated strings or regex patterns). Checked in `VideoSpeedExtension.initialize()` via `this.isBlacklisted(config.settings.blacklist)` [`src/content/inject.js:46-49`].

**Downstream** (`DomUtils.isBlacklisted(blacklist)`) [`src/utils/dom-utils.js:24-62`]:
1. Splits blacklist by `\n`.
2. For each entry: strips leading/trailing whitespace via `regStrip`.
3. If entry starts with `/`: parsed as a regex (split on `/`, last segment as flags if valid).
4. Otherwise: treated as a literal string, escaped via `escapeStringRegExp`.
5. Tests `regexp.test(location.href)`.

Default blacklisted hosts: `www.instagram.com`, `imgur.com`, `teams.microsoft.com`, `meet.google.com` (plus `hangouts.google.com` and `meet.google.com` excluded at manifest level).

**Files involved**: `src/utils/dom-utils.js:24-62`, `src/utils/constants.js:54-57`.

---

### 3.28 Media Element Discovery — MutationObserver

**What it does**: Monitors the DOM for dynamically added or removed `<video>` and `<audio>` elements, and dispatches `onVideoFound`/`onVideoRemoved` callbacks.

**Upstream**: Started in `VideoSpeedExtension.deferExpensiveOperations` via `mutationObserver.start(document)` [`src/content/inject.js:121-123`].

**Downstream** (`VideoMutationObserver.start(document)`) [`src/observers/mutation-observer.js:22-41`]:
- Creates a `MutationObserver` with `{ childList: true, subtree: true, attributeFilter: ['aria-hidden', 'data-focus-method', 'style', 'class'] }`.
- Each batch of mutations is processed via `requestIdleCallback` (timeout 2000ms).

**Mutation processing** [`src/observers/mutation-observer.js:48-127`]:
- `childList` mutations: calls `checkForVideoAndShadowRoot(node, parent, added)` for each added/removed element node.
  - If `node.nodeName === 'VIDEO'` (or `'AUDIO'` when audio enabled): calls `onVideoFound` or `onVideoRemoved`.
  - If node has a `shadowRoot`: calls `observeShadowRoot(shadowRoot)` and recursively processes shadow children.
  - Recursively processes `node.children`.
- `attributes` mutations on `style`/`class`: calls `handleVisibilityChanges(element)` → `recheckVideoElement(video)` which may attach or remove controllers, or call `video.vsc.updateVisibility()`.
- `attributes` mutations where `aria-hidden === 'false'` or `nodeName === 'APPLE-TV-PLUS-PLAYER'`: uses `DomUtils.getShadow(document.body)` to find all video nodes and re-checks them (special Apple TV+ logic).

**Shadow root observation**: Each unique shadow root gets its own `MutationObserver` instance, tracked in `this.shadowObservers` (a `Set`) [`src/observers/mutation-observer.js:244-268`]. Shadow observers use `requestIdleCallback` with a 500ms timeout.

**Files involved**: `src/observers/mutation-observer.js`, `src/content/inject.js:120-123`.

---

### 3.29 Media Element Discovery — MediaElementObserver

**What it does**: Provides methods to scan the document for existing `<video>` and `<audio>` elements, including those nested in shadow DOMs, iframes, and site-specific containers.

**Upstream**: Instantiated in `VideoSpeedExtension.setupObservers()` [`src/content/inject.js:227`]; scan methods called from `deferredMediaScan` and `scheduleComprehensiveScan`.

**Key methods** [`src/observers/media-observer.js`]:
- `scanForMediaLight(document)`: Queries `document.querySelectorAll(mediaTagSelector)` only (no shadow DOM traversal). Also calls `siteHandler.detectSpecialVideos(document)`. Fast path for initial scan.
- `scanForMedia(document)`: Full scan including recursive shadow DOM traversal via an inline `findShadowMedia` function, plus `siteHandler.detectSpecialVideos(document)`. Filters results through `siteHandler.shouldIgnoreVideo(media)`.
- `scanIframes(document)`: Iterates `document.getElementsByTagName('iframe')`, tries to access `contentDocument` (same-origin only), recursively calls `scanForMedia`.
- `scanSiteSpecificContainers(document)`: Queries `siteHandler.getVideoContainerSelectors()` containers, then calls `DomUtils.findMediaElements` on each.
- `scanAll(document)`: Combines `scanForMedia` + `scanSiteSpecificContainers` + `scanIframes`, deduplicates via `new Set(allMedia)`.
- `isValidMediaElement(media)`: Returns false if not connected to DOM, if audio when `audioBoolean` disabled, or if `siteHandler.shouldIgnoreVideo(media)` returns true.
- `shouldStartHidden(media)`: Returns true if audio and `audioBoolean` disabled, or if audio is `disabled` or has `pointerEvents: none`. For video, returns true if `display: none`, `visibility: hidden`, or `opacity: 0`.

**Files involved**: `src/observers/media-observer.js`.

---

### 3.30 Shadow DOM Media Search

**What it does**: Recursively finds `<video>`/`<audio>` elements inside arbitrarily nested shadow roots.

**Downstream** (`DomUtils.findShadowMedia(root, selector)`) [`src/utils/dom-utils.js:200-224`]:
1. If `root.shadowRoot`: recurses into it.
2. Queries `root.querySelectorAll(selector)`.
3. For every element in `root.querySelectorAll('*')`: recurses into elements with `shadowRoot`.

`DomUtils.getShadow(parent, maxDepth=10)` [`src/utils/dom-utils.js:82-113`] provides a flat array of all descendant elements including those in shadow DOMs, using a `WeakSet` to prevent infinite loops, with depth limiting.

**Files involved**: `src/utils/dom-utils.js:82-224`.

---

### 3.31 Site-Specific Overrides

The `SiteHandlerManager` (instantiated as `window.VSC.siteHandlerManager` by `index.js`) selects the appropriate handler at runtime by iterating `availableHandlers` and calling `HandlerClass.matches()` [`src/site-handlers/index.js:36-46`]. If no handler matches, `BaseSiteHandler` is used.

#### YouTube Handler (`YouTubeHandler`)

**Matches**: `location.hostname === 'www.youtube.com'` [`src/site-handlers/youtube-handler.js:13-15`].

**Controller positioning**: Inserts into `parent.parentElement` (one level up) via `firstChild` method, to appear above YouTube's overlay layers [`src/site-handlers/youtube-handler.js:23-32`].

**shouldIgnoreVideo**: Returns true for elements with class `video-thumbnail` or whose parent has class `ytp-ad-player-overlay` (ignores ad overlay videos) [`src/site-handlers/youtube-handler.js:60-66`].

**getVideoContainerSelectors**: Returns `['.html5-video-player', '#movie_player', '.ytp-player-content']` [`src/site-handlers/youtube-handler.js:72-74`].

**detectSpecialVideos**: Queries `iframe[src*="youtube.com"]` elements and collects videos from accessible same-origin iframes [`src/site-handlers/youtube-handler.js:81-103`].

**CSS overrides in `inject.css`**:
- `.ytp-hide-info-bar .vsc-controller`: `position: relative; top: 10px` [`src/styles/inject.css:29-32`].
- `.ytp-autohide .vsc-controller`: hidden with opacity transition [`src/styles/inject.css:35-38`].
- `.ytp-autohide .vsc-show`: visible [`src/styles/inject.css:40-43`].
- `.html5-video-player:not(.ytp-hide-info-bar) .vsc-controller`: `position: relative; top: 60px` (embedded) [`src/styles/inject.css:47-50`].

#### Netflix Handler (`NetflixHandler`)

**Matches**: `location.hostname === 'www.netflix.com'` [`src/site-handlers/netflix-handler.js:13-15`].

**Controller positioning**: Inserts `beforeParent` (before `parent.parentElement`) to bypass Netflix's overlay [`src/site-handlers/netflix-handler.js:23-29`].

**handleSeek**: Sends `window.postMessage({ action: 'videospeed-seek', seekMs: seekSeconds * 1000 }, 'https://www.netflix.com')` [`src/site-handlers/netflix-handler.js:38-57`]. The `netflix.js` page-context script listens for this message and calls `videoPlayer.getVideoPlayerBySessionId(playerSessionId).seek(currentTime + event.data.seekMs)` using Netflix's internal `window.netflix.appContext` API [`src/site-handlers/scripts/netflix.js:1-7`].

**shouldIgnoreVideo**: Returns true for elements with class `preview-video` or whose parent has class `billboard-row` [`src/site-handlers/netflix-handler.js:78-84`].

**Netflix script injection**: Done by `injector.js` (content script context) since `chrome.runtime.getURL` is needed [`src/content/injector.js:94-96`].

**CSS overrides**: `#netflix-player:not(.player-cinema-mode) .vsc-controller`: `position: relative; top: 85px` [`src/styles/inject.css:72-75`].

#### Amazon Handler (`AmazonHandler`)

**Matches**: `www.amazon.com`, `www.primevideo.com`, any hostname including `amazon.` or `primevideo.` [`src/site-handlers/amazon-handler.js:13-19`].

**Controller positioning**: For non-`.vjs-tech` videos (Prime Video), inserts `beforeParent`. For `.vjs-tech` videos (product page), uses default `firstChild` [`src/site-handlers/amazon-handler.js:28-41`].

**shouldIgnoreVideo**: Ignores videos with `readyState >= 2` and `rect.width < 200 || rect.height < 100` (small product previews) [`src/site-handlers/amazon-handler.js:48-57`].

**CSS overrides**: `.dv-player-fullscreen .vsc-controller { height: 0 }` (prevents fullscreen overlay issue) [`src/styles/inject.css:110-112`].

#### Apple TV+ Handler (`AppleHandler`)

**Matches**: `location.hostname === 'tv.apple.com'` [`src/site-handlers/apple-handler.js:13-15`].

**Controller positioning**: Inserts into `parent.parentNode` via `firstChild` [`src/site-handlers/apple-handler.js:23-29`].

**detectSpecialVideos**: Queries the custom `<apple-tv-plus-player>` element and returns videos found in its `shadowRoot` [`src/site-handlers/apple-handler.js:45-53`].

**Mutation observer special case**: When `aria-hidden` becomes `false` or a node named `APPLE-TV-PLUS-PLAYER` mutates, the mutation observer re-processes all shadow DOM videos found via `DomUtils.getShadow(document.body)` [`src/observers/mutation-observer.js:106-126`].

#### Facebook Handler (`FacebookHandler`)

**Matches**: `location.hostname === 'www.facebook.com'` [`src/site-handlers/facebook-handler.js:13-15`].

**Controller positioning**: Traverses 7 levels up from `parent` to find the correct insertion point (characterized in a code comment as "a monstrosity") [`src/site-handlers/facebook-handler.js:29-35`].

**initialize**: Sets up a dedicated `MutationObserver` on `document.body` watching for dynamically added video elements [`src/site-handlers/facebook-handler.js:60-86`]. The `onNewVideosDetected` callback currently only logs; it does not attach controllers directly.

**shouldIgnoreVideo**: Ignores videos inside `[data-story-id]`, `.story-bucket-container`, or with `data-video-width="0"` [`src/site-handlers/facebook-handler.js:104-110`].

**cleanup**: Disconnects the Facebook-specific `MutationObserver` [`src/site-handlers/facebook-handler.js:124-130`].

**CSS overrides**: `#facebook .vsc-controller { position: relative; top: 40px }` [`src/styles/inject.css:53-56`].

---

### 3.32 Background Service Worker Messaging

**What it does**: Tracks which tabs have active controllers and updates the extension icon accordingly (red = active controllers, gray = none).

**Upstream**: Content script forwards `VSC_CONTROLLER_CREATED`/`VSC_CONTROLLER_REMOVED` window events to the background via `chrome.runtime.sendMessage` [`src/content/injector.js:205-239`].

**Message handlers in `background.js`** [`src/background.js:60-103`]:
- `VSC_CONTROLLER_CREATED`: Adds `controllerId` to `tabControllers.get(tabId)` Set; calls `updateTabIndicators(tabId, true)`.
- `VSC_CONTROLLER_REMOVED`: Removes `controllerId`; if Set becomes empty, deletes entry and calls `updateTabIndicators(tabId, false)`.
- `VSC_QUERY_ACTIVE_CONTROLLERS`: Returns `{ hasActiveControllers, controllerCount }` synchronously (returns `true` to keep channel open for async response).

**Tab lifecycle handlers** [`src/background.js:109-146`]:
- `tabs.onUpdated`: On `status === 'loading'` with URL, clears tracking and sets icon to inactive.
- `tabs.onRemoved`: Clears tracking.
- `tabs.onActivated`: Re-applies correct icon state for the newly focused tab.

**Icon update** (`updateIcon`) [`src/background.js:14-45`]:
- Calls `chrome.action.setIcon({ tabId, path: { "19": ..., "38": ..., "48": ... } })`.
- Active: uses `icon19.png`, `icon38.png`, `icon48.png` (red icons).
- Inactive: uses `icon19_disabled.png`, `icon38_disabled.png`, `icon48_disabled.png` (gray icons).
- On "No tab with id" error: cleans up stale tracking.

**Files involved**: `src/background.js`, `src/content/injector.js:205-239`, `src/core/video-controller.js:46-50` (dispatch creation event), `src/core/video-controller.js:315-319` (dispatch removal event).

---

### 3.33 Module Loader (`module-loader.js`)

**What it does**: Provides a lightweight `window.defineModule`/`window.loadModule` system mimicking AMD/CommonJS for dynamic script loading.

**Upstream**: Loaded as a web-accessible resource; `window.VSC.logger.debug('Module loader initialized')` is called at the end of the file, requiring `window.VSC.logger` to already exist [`src/module-loader.js:72`].

**Key functions** [`src/module-loader.js`]:
- `window.defineModule(name, dependencies, factory)`: Registers a module. Resolves dependencies via `Promise.all`, calls `factory`, registers result on `moduleRegistry`.
- `window.loadModule(name)`: Returns cached module if present; otherwise injects a `<script>` tag with `src = chrome.runtime.getURL("src/${name}.js")` and waits for it to self-register.

Note: `module-loader.js` is listed as a web-accessible resource and registered as a global on `window`, but it is not explicitly included in the `injectModules` script list in `injector.js`. It appears to be an auxiliary utility available if needed but not currently in the primary boot chain.

---

### 3.34 Controller Removal and Cleanup

**What it does**: Tears down a controller: removes DOM element, removes event listeners, disconnects the mutation observer, removes from config tracking, deletes `video.vsc`, and dispatches `VSC_CONTROLLER_REMOVED`.

**Upstream**:
- `VideoSpeedExtension.onVideoRemoved(video)` calls `video.vsc.remove()` [`src/content/inject.js:281-290`].
- `VideoMutationObserver.recheckVideoElement(video)` may call `video.vsc.remove()` when a video becomes invalid [`src/observers/mutation-observer.js:166-170`].
- `VideoSpeedExtension.cleanup()` on `beforeunload` calls `video.vsc.remove()` for all tracked elements [`src/content/inject.js:311-335`].

**Downstream** (`VideoController.remove()`) [`src/core/video-controller.js:285-320`]:
1. `this.div.remove()` — removes DOM wrapper.
2. `video.removeEventListener('play', handlePlay)` and `video.removeEventListener('seeked', handleSeek)`.
3. `this.targetObserver.disconnect()`.
4. `config.removeMediaElement(this.video)`.
5. `delete this.video.vsc`.
6. `dispatchControllerEvent('VSC_CONTROLLER_REMOVED', { controllerId, videoSrc, tagName })`.

---

### 3.35 Controller Visibility — Auto-Update

**What it does**: When a video's visibility changes (tracked by `handleVisibilityChanges` in the mutation observer), the controller show/hide state is synchronized.

**Upstream**: Attribute mutation on `style` or `class` of a video element or container → `VideoMutationObserver.handleVisibilityChanges` → `recheckVideoElement(video)` → `video.vsc.updateVisibility()`.

**Downstream** (`VideoController.updateVisibility()`) [`src/core/video-controller.js:371-408`]:
- For `AUDIO` elements: hides if `audioBoolean` disabled; shows if `audioBoolean` enabled and not `vsc-manual`.
- For `VIDEO` elements: removes `vsc-hidden` when video becomes visible (and controller isn't manually hidden or `startHidden` is set). Adds `vsc-hidden` when video becomes invisible.

---

### 3.36 ForceLastSavedSpeed

**What it does**: An option that makes the extension override the playback rate whenever the page or the media element itself fires a `ratechange` event with a different value. Used to prevent streaming sites from resetting the speed.

**Upstream**: `config.settings.forceLastSavedSpeed = true`.

**Downstream**:
1. `VideoController.initializeSpeed()`: Instead of `video.playbackRate = targetSpeed`, dispatches a custom `ratechange` event with `detail = { origin: 'videoSpeed', speed: targetSpeed }` [`src/core/video-controller.js:86-96`].
2. `ActionHandler.setSpeed()`: Same — dispatches custom `ratechange` event instead of direct assignment [`src/core/action-handler.js:316-323`].
3. `EventManager.handleRateChange()`: Intercepts all `ratechange` events. If `detail.origin !== 'videoSpeed'`, overrides `video.playbackRate = config.settings.lastSpeed` and stops propagation [`src/utils/event-manager.js:336-344`].

---

### 3.37 Debug Helper

**What it does**: Provides console inspection utilities accessible at `window.vscDebugHelper` (instance) and `window.vscDebug` (when enabled).

**Upstream**: `debug-helper.js` is injected as part of the module list and instantiates `window.vscDebugHelper = new DebugHelper()` at load time [`src/utils/debug-helper.js:396-401`]. Debug mode requires explicit call: `window.vscDebugHelper.enable()`.

**Methods** [`src/utils/debug-helper.js`]:
- `enable()`: Sets logger verbosity to DEBUG, creates `window.vscDebug` object.
- `checkMedia()`: Logs detailed info for all `<video>`/`<audio>` elements and shadow DOM media.
- `checkControllers()`: Logs state of all `.vsc-controller` elements.
- `testPopupCommunication()`: Tests that action handler is available and performs a test speed change.
- `testPopupMessageBridge()`: Simulates `VSC_MESSAGE` events with 1.5-second delays.
- `forceShowControllers()`: Removes all hide classes and forces display/visibility/opacity styles on all controllers.
- `forceShowAudioControllers()`: Same, but only for controllers associated with `<audio>` elements.
- `getElementVisibility(element)`: Returns a visibility summary object.
- `monitorControllerChanges()`: Creates a MutationObserver on `document.body` watching for class/style changes on `.vsc-controller` elements.

---

### 3.38 Logger

**What it does**: A leveled logging utility. Logs are gated by a verbosity setting; all output goes to `console.log`.

**Levels** (from `LOG_LEVELS` in constants) [`src/utils/constants.js:64-71`]: NONE(1), ERROR(2), WARNING(3), INFO(4), DEBUG(5), VERBOSE(6).

**Default verbosity**: 3 (WARNING) at construction time; updated to `config.settings.logLevel` (default 3) after settings are loaded.

**Methods**: `log(message, level)`, `error(message)`, `warn(message)`, `info(message)`, `debug(message)`, `verbose(message)`. VERBOSE level additionally calls `console.trace()` [`src/utils/logger.js:54-56`].

**Note**: The `error` method in the logger calls `console.log` with prefix `ERROR:`, not `console.error` [`src/utils/logger.js:43-45`].

---

## 4. Inter-Module Dependency Graph

The dependency direction is: later-loaded modules depend on earlier-loaded ones via `window.VSC.*`.

```
constants.js
    |
    v
logger.js ──────────────────────────────────────────────┐
    |                                                    |
    v                                                    |
debug-helper.js                                         |
    |                                                    |
    v                                                    |
dom-utils.js                                            |
    |                                                    |
    v                                                    |
event-manager.js ───────────────────────────────────────|
    |                                                    |
    v                                                    |
storage-manager.js                                      |
    |                                                    |
    v                                                    |
settings.js (VideoSpeedConfig)                          |
    |                                                    |
    v                                                    |
media-observer.js                                       |
    |                                                    |
    v                                                    |
mutation-observer.js                                    |
    |                                                    |
    v                                                    |
action-handler.js                                       |
    |                                                    |
    v                                                    |
video-controller.js                                     |
    |                                                    |
    v                                                    |
controls.js ─────────────────────────────────────────── |
    |                                                    |
    v                                                    |
drag-handler.js                                         |
    |                                                    |
    v                                                    |
shadow-dom.js                                           |
    |                                                    |
    v                                                    |
base-handler.js → netflix-handler.js → youtube-handler.js → facebook-handler.js → amazon-handler.js → apple-handler.js
    |
    v
site-handlers/index.js (SiteHandlerManager, siteHandlerManager singleton)
    |
    v
inject.js (VideoSpeedExtension, extension instance)
```

Key bidirectional references (set after construction):
- `EventManager.actionHandler` ← `ActionHandler` (set in `inject.js:60`)
- `ActionHandler.eventManager` ← `EventManager` (set in `ActionHandler` constructor argument)
- `VideoController` → `ControlsManager` (created in constructor)
- `VideoController` → `ActionHandler` (passed in constructor)

---

## 5. Chrome Extension API Surface

| API Call | Location | Purpose |
|----------|----------|---------|
| `chrome.action.setIcon({tabId, path})` | `src/background.js:20-27` | Update tab icon (active/inactive) |
| `chrome.action.setIcon({path})` | `src/background.js:153-159` | Set default icon state |
| `chrome.action.setIcon({path})` | `src/ui/popup/popup.js:50-56` | Update icon from popup on enable/disable |
| `chrome.runtime.getURL(path)` | `src/content/injector.js:10` | Resolve extension resource URL for script injection |
| `chrome.runtime.getURL(path)` | `src/content/injector.js:27` | Resolve CSS URL |
| `chrome.runtime.getURL(path)` | `src/background.js:23-25` | Resolve icon URLs |
| `chrome.runtime.getURL(path)` | `src/ui/popup/popup.js:51-55` | Resolve icon URLs |
| `chrome.runtime.getURL(path)` | `src/module-loader.js:51-54` | Load module scripts |
| `chrome.runtime.onMessage.addListener` | `src/background.js:60` | Handle controller lifecycle messages |
| `chrome.runtime.onMessage.addListener` | `src/content/injector.js:159` | Bridge popup→page messages |
| `chrome.runtime.sendMessage` | `src/content/injector.js:209-216` | Forward VSC_CONTROLLER_CREATED to background |
| `chrome.runtime.sendMessage` | `src/content/injector.js:225-232` | Forward VSC_CONTROLLER_REMOVED to background |
| `chrome.runtime.onInstalled.addListener` | `src/background.js:182` | Initialize on install/update |
| `chrome.runtime.onStartup.addListener` | `src/background.js:169` | Initialize on browser start |
| `chrome.runtime.lastError` | `src/background.js:30-37` | Check for errors after async calls |
| `chrome.storage.sync.get(null, cb)` | `src/content/injector.js:141-152` | Diagnostic keydown logging |
| `chrome.storage.sync.get(null, cb)` | `src/content/injector.js:246-250` | Fetch all settings for injection |
| `chrome.storage.sync.get(defaults, cb)` | `src/core/storage-manager.js:36-40` | Load settings in extension context |
| `chrome.storage.sync.get(null, cb)` | `src/ui/popup/popup.js:26-28` | Read initial enabled state |
| `chrome.storage.sync.get(null, cb)` | `src/ui/popup/popup.js:73-93` | Load settings for popup UI |
| `chrome.storage.sync.set(data, cb)` | `src/content/injector.js:179-190` | Save settings from page context (bridge) |
| `chrome.storage.sync.set(data, cb)` | `src/core/storage-manager.js:93-97` | Save settings in extension context |
| `chrome.storage.sync.set(data, cb)` | `src/utils/event-manager.js:380-384` | Save lastSpeed on ratechange |
| `chrome.storage.sync.set(data, cb)` | `src/ui/popup/popup.js:31-39` | Save enabled state |
| `chrome.storage.sync.remove(keys, cb)` | `src/core/storage-manager.js:124-128` | Remove keys |
| `chrome.storage.sync.remove(keys)` | `src/ui/options/options.js:294-306` | Remove legacy setting keys |
| `chrome.storage.sync.clear(cb)` | `src/core/storage-manager.js:136-140` | Clear all storage |
| `chrome.storage.onChanged.addListener` | `src/core/storage-manager.js:149-153` | Listen for storage changes |
| `chrome.tabs.query({active, currentWindow}, cb)` | `src/ui/popup/popup.js:154-162` | Get active tab for setSpeed |
| `chrome.tabs.query({active, currentWindow}, cb)` | `src/ui/popup/popup.js:165-173` | Get active tab for adjustSpeed |
| `chrome.tabs.query({active, currentWindow}, cb)` | `src/ui/popup/popup.js:176-181` | Get active tab for resetSpeed |
| `chrome.tabs.sendMessage(tabId, message)` | `src/ui/popup/popup.js:156-160` | Send speed command to content script |
| `chrome.tabs.sendMessage(tabId, message)` | `src/ui/popup/popup.js:167-171` | Send speed adjustment to content script |
| `chrome.tabs.sendMessage(tabId, message)` | `src/ui/popup/popup.js:179-181` | Send reset to content script |
| `chrome.tabs.onUpdated.addListener` | `src/background.js:109` | Handle page navigation |
| `chrome.tabs.onRemoved.addListener` | `src/background.js:123` | Handle tab close |
| `chrome.tabs.onActivated.addListener` | `src/background.js:133` | Handle tab switch |

---

## 6. Event & Message Bus

### Custom DOM Events (dispatched on `window`)

| Event Name | Dispatch Location | Payload (`detail`) | Receiver |
|-----------|-------------------|-------------------|---------|
| `VSC_USER_SETTINGS` | `src/content/injector.js:253-257` | `{ ...storageContents }` | `StorageManager._setupSettingsListener` in `storage-manager.js:17-22` |
| `VSC_SAVE_SETTINGS` | `src/core/storage-manager.js:104-108` | `{ ...settingsData }` | `injector.js:175-197` → `chrome.storage.sync.set` |
| `VSC_MESSAGE` | `src/content/injector.js:163-167` | `{ type: 'VSC_*', payload: {...} }` | `inject.js:340-392` switch handler |
| `VSC_CONTROLLER_CREATED` | `src/core/video-controller.js:417-421` | `{ controllerId, videoSrc, tagName }` | `injector.js:205-221` → `chrome.runtime.sendMessage` |
| `VSC_CONTROLLER_REMOVED` | `src/core/video-controller.js:417-421` | `{ controllerId, videoSrc, tagName }` | `injector.js:223-239` → `chrome.runtime.sendMessage` |
| `VSC_KEYBINDING_DIAGNOSTIC` | `src/utils/event-manager.js:65-69` | `{ stage, timestamp, source, details }` | `injector.js:200-202` → `console.warn` |
| `VSC_KEYBINDING_DIAGNOSTIC` | `src/core/action-handler.js:59-63` | same | same |

### Chrome Runtime Messages (content script ↔ background)

| Message Type | Sender | Receiver | Payload |
|-------------|--------|----------|---------|
| `VSC_CONTROLLER_CREATED` | `injector.js:209-215` | `background.js:66-75` | `{ type, controllerId, timestamp }` |
| `VSC_CONTROLLER_REMOVED` | `injector.js:225-231` | `background.js:78-93` | `{ type, controllerId, timestamp }` |
| `VSC_QUERY_ACTIVE_CONTROLLERS` | (potential sender) | `background.js:95-103` | (none) → response: `{ hasActiveControllers, controllerCount }` |

### Chrome Runtime Messages (popup → content script)

| Message Type | Sender | Forwarded By | Final Handler |
|-------------|--------|-------------|---------------|
| `VSC_SET_SPEED` | `popup.js:156-160` | `injector.js` `onMessage` → `VSC_MESSAGE` event | `inject.js:348-358` |
| `VSC_ADJUST_SPEED` | `popup.js:167-171` | same | `inject.js:361-373` |
| `VSC_RESET_SPEED` | `popup.js:179-181` | same | `inject.js:375-381` |
| `VSC_TOGGLE_DISPLAY` | (defined in constants, not sent by popup.js currently) | same | `inject.js:383-389` |

### `postMessage` (page-context inter-frame)

| Location | Payload | Receiver |
|----------|---------|---------|
| `src/site-handlers/netflix-handler.js:41-46` | `{ action: 'videospeed-seek', seekMs: number }` | `src/site-handlers/scripts/netflix.js:1-7` (validates `origin === 'https://www.netflix.com'`) |

### Native DOM Events Listened To

| Event | Element | Captured | Handler | File |
|-------|---------|----------|---------|------|
| `keydown` | `document` (+ `window.top.document` in iframe) | yes (capture) | `EventManager.handleKeydown` | `src/utils/event-manager.js:136-147` |
| `ratechange` | `document` | yes (capture) | `EventManager.handleRateChange` | `src/utils/event-manager.js:307-318` |
| `play` | `video` | no | `VideoController.mediaEventAction` | `src/core/video-controller.js:251` |
| `seeked` | `video` | no | `VideoController.mediaEventAction` | `src/core/video-controller.js:252` |
| `keydown` | `window` | yes (capture) | Diagnostic logging only | `src/content/injector.js:123-156` |
| `VSC_SAVE_SETTINGS` | `window` | no | `chrome.storage.sync.set` | `src/content/injector.js:175-197` |
| `VSC_CONTROLLER_CREATED` | `window` | no | `chrome.runtime.sendMessage` | `src/content/injector.js:205-221` |
| `VSC_CONTROLLER_REMOVED` | `window` | no | `chrome.runtime.sendMessage` | `src/content/injector.js:223-239` |
| `VSC_KEYBINDING_DIAGNOSTIC` | `window` | no | `console.warn` in content script | `src/content/injector.js:200-202` |
| `VSC_MESSAGE` | `window` | no | Speed/display actions | `src/content/inject.js:340-392` |
| `VSC_USER_SETTINGS` | `window` | no | `StorageManager._injectedSettings = event.detail` | `src/core/storage-manager.js:17-22` |
| `mousedown` | `.draggable` (shadow) | yes (capture) | `DragHandler.handleDrag` | `src/ui/controls.js:34-42` |
| `click` | buttons (shadow) | yes (capture) | `ActionHandler.runAction` | `src/ui/controls.js:52-64` |
| `wheel` | `#controller` (shadow) | no (passive: false) | Speed change | `src/ui/controls.js:86-111` |
| `click` | `#controller` (shadow) | no | `e.stopPropagation()` | `src/ui/controls.js:123` |
| `mousedown` | `#controller` (shadow) | no | `e.stopPropagation()` | `src/ui/controls.js:124` |
| `touchstart` | buttons (shadow) | yes (capture) | `e.stopPropagation()` | `src/ui/controls.js:67-73` |
| `mousemove` | `parentElement` | no | `DragHandler.startDragging` | `src/ui/drag-handler.js:52` |
| `mouseup` | `parentElement` | no | `DragHandler.stopDragging` | `src/ui/drag-handler.js:50` |
| `mouseleave` | `parentElement` | no | `DragHandler.stopDragging` | `src/ui/drag-handler.js:51` |
| `beforeunload` | `window` | no | `extension.cleanup()` | `src/content/inject.js:398-400` |
| MutationObserver | `document` | — | `VideoMutationObserver.processMutations` | `src/observers/mutation-observer.js:23-30` |
| MutationObserver | `video` element | — | `VideoController.setupMutationObserver` | `src/core/video-controller.js:260-280` |
| MutationObserver | `shadowRoot` | — | `VideoMutationObserver.observeShadowRoot` | `src/observers/mutation-observer.js:249-264` |
| MutationObserver | `document.body` | — | `FacebookHandler.setupFacebookObserver` | `src/site-handlers/facebook-handler.js:62-84` |

---

## 7. Test Coverage Map

### Test Runner Architecture

Tests are run by `tests/run-tests.js` using Node.js + JSDOM (`jsdom` package). A global JSDOM environment is created and shared across all test files. Chrome APIs are mocked globally before the JSDOM setup. `requestIdleCallback` is polyfilled as `setTimeout(fn, 0)`. Shadow DOM (`attachShadow`) is polyfilled with a JSDOM-compatible mock `div` [`tests/run-tests.js:80-118`].

The test runner supports three modes: `unit`, `integration`, or all (default). Each test file exports a `SimpleTestRunner` instance which is auto-discovered by checking for a `.run` method [`tests/run-tests.js:180`].

### Test Helpers

**`tests/helpers/chrome-mock.js`**:
- Exports `chromeMock`, `installChromeMock()`, `cleanupChromeMock()`, `resetMockStorage()`.
- `chromeMock.storage.sync.get`: simulates async with `setTimeout(10ms)`, returns from `mockStorage` with default fallback.
- `chromeMock.storage.sync.set`: merges into `mockStorage` with `setTimeout` callback.
- `chromeMock.runtime.getURL`: returns `chrome-extension://test-extension/${path}`.
- `chromeMock.tabs.query`: always returns `[{ id: 1, active: true, url: 'https://www.youtube.com/...' }]`.

**`tests/helpers/test-utils.js`**:
- `createMockVideo(options)`: Real JSDOM `<video>` with `Object.defineProperties` overriding `playbackRate`, `currentTime`, `duration`, `currentSrc`, `paused`, `muted`, `volume`, `ownerDocument`. Mocks `play()`, `pause()`, `getBoundingClientRect()`, `addEventListener/removeEventListener/dispatchEvent`.
- `createMockAudio(options)`: Similar for `<audio>`.
- `createMockDOM()`: Appends a `<div id="test-container">` to `document.body`; returns cleanup function.
- `createMockEvent`, `createMockKeyboardEvent`.
- `assert`: Custom assertion functions (`equal`, `true`, `false`, `exists`, `throws`, `deepEqual`).
- `SimpleTestRunner`: `test(name, fn)`, `beforeEach(fn)`, `afterEach(fn)`, `run()`.

**`tests/helpers/module-loader.js`**:
- `loadCoreModules()`: Sequential `await import(...)` for all source files in dependency order.
- `loadInjectModules()`: `loadCoreModules()` + `inject.js`.
- `loadMinimalModules()`: constants, logger, storage-manager, settings only.
- `loadObserverModules()`: logger, dom-utils, mutation-observer only (used by observer tests and icon-integration tests, but icon test also imports VideoController/ActionHandler which require more).

### Unit Tests

**`tests/unit/core/settings.test.js`** (uses `loadMinimalModules`):
- Verifies `VideoSpeedConfig` initializes with `enabled: true`, `lastSpeed: 1.0`, `logLevel: 3`.
- Verifies `load()` returns settings from storage.
- Verifies `save()` persists settings and updates `this.settings`.
- Verifies `getKeyBinding`/`setKeyBinding` work correctly.
- Verifies `addMediaElement`/`removeMediaElement`/`getMediaElements` tracking.
- Verifies graceful handling of nonexistent binding lookups.

**`tests/unit/core/action-handler.test.js`** (uses `loadCoreModules`):
- Tests `setSpeed` directly: verifies `video.playbackRate`, `speedIndicator.textContent`, `config.settings.lastSpeed`.
- Tests `runAction('faster', 0.1)` increases speed by 0.1.
- Tests `runAction('slower', 0.1)` decreases speed by 0.1.
- Tests speed limits: `faster` at 16.0 stays at 16.0; `slower` at 0.07 stays at 0.07.
- Tests `pause` action toggles `video.paused`.
- Tests `muted` action toggles `video.muted`.
- Tests `louder`/`softer` actions on `video.volume`.
- Tests `advance`/`rewind` on `video.currentTime`.
- Tests `mark` sets `video.vsc.mark` and `jump` restores `video.currentTime`.
- Tests mark/jump through `EventManager.handleKeydown` (M=77, J=74 key simulation).
- Tests `display` action toggles `vsc-hidden`/`vsc-manual` classes.
- Tests actions on videos inside nested shadow DOM (2 levels).

**`tests/unit/core/video-controller.test.js`** (uses `loadCoreModules`):
- Tests `VideoController` constructor attaches to video, creates DOM, sets `video.vsc`.
- Tests deduplication: second constructor call with same video returns existing controller.
- Tests speed initialization with `rememberSpeed + lastSpeed = 2.0` sets `video.playbackRate = 2.0`.
- Tests that `controller.div.classList.contains('vsc-controller')` is true.
- Tests `vsc-nosource` class for video with empty `currentSrc`.
- Tests `vsc-hidden` class when `config.settings.startHidden = true`.
- Tests `remove()` clears `video.vsc`, removes from `config.getMediaElements()`.
- Tests multiple controllers tracked in `config`.

**`tests/unit/core/icon-integration.test.js`** (uses `loadObserverModules`):
- Tests `VSC_CONTROLLER_CREATED` event is dispatched with `controllerId`, `videoSrc`, `tagName`.
- Tests `VSC_CONTROLLER_REMOVED` event is dispatched on `controller.remove()`.
- Tests that two controllers have unique `controllerId` values.
- Tests audio elements dispatch `VSC_CONTROLLER_CREATED` with `tagName === 'AUDIO'`.

**`tests/unit/core/keyboard-shortcuts-saving.test.js`** (uses `loadMinimalModules`):
- Tests `DEFAULT_SETTINGS.keyBindings` exists, is non-empty, has all 9 expected actions.
- Tests all bindings have correct types (`action: string`, `key: number`, `value: number`, `force: boolean`, `predefined: boolean`).
- Tests fresh install gets default bindings without errors.
- Tests existing storage bindings are preserved and loaded correctly.
- Tests `save`/`load` round-trips preserve binding values and `force` is always boolean.
- Tests string `force` values from legacy storage are handled correctly.
- Tests that `slower`, `faster`, `display` bindings are always present.
- Tests fresh install always has all 9 required default shortcuts.

**`tests/unit/core/f-keys.test.js`** (uses `loadMinimalModules` with extra imports):
- Tests F13–F24 key codes (124–135) can be stored and loaded as `keyBindings`.
- Tests special key codes (NumLock=144, ScrollLock=145, Pause=19, PrintScreen=44, media keys 173-179) are accepted.
- Tests `BLACKLISTED_KEYCODES` (9, 16, 17, 18, 91, 92, 93, 224) are blacklisted; F13(124), A(65), Space(32), Enter(13) are not.
- Tests `EventManager.handleKeydown` with F13 (keyCode 124) triggers the bound `faster` action.
- Note: The test calls `loadMinimalModules` with additional paths as array argument, but `loadMinimalModules` in `tests/helpers/module-loader.js` does not accept arguments — this test has a latent bug.

**`tests/unit/observers/mutation-observer.test.js`** (uses `loadObserverModules`):
- Tests `processChildListMutation` fires `onVideoFound` for video nodes, skips divs and text/comment nodes.
- Tests `onVideoRemoved` is fired for removed video nodes that have `vsc`.
- Tests null/undefined nodes are skipped gracefully.
- Tests `checkForVideoAndShadowRoot` finds video in shadow root and calls `onVideoFound`.
- Tests `checkForVideoAndShadowRoot` recursively finds nested video in container.

**`tests/unit/observers/audio-size-handling.test.js`** (uses `loadObserverModules`):
- Tests `MediaElementObserver.isValidMediaElement` accepts small audio when `audioBoolean: true`.
- Tests `MediaElementObserver.isValidMediaElement` rejects audio when `audioBoolean: false`.
- Tests `VideoController` starts visible for small audio when `shouldStartHidden` returns false.
- Tests `MediaElementObserver.isValidMediaElement` accepts all video sizes.
- Tests `shouldStartHidden` returns false for small video (size checks removed per assertion).
- Tests display toggle works correctly with audio controllers.
- Note: Test constants `SMALL_AUDIO_SIZE.WIDTH = 20` are described as "below AUDIO_MIN_WIDTH (25)" but `CONTROLLER_SIZE_LIMITS.AUDIO_MIN_WIDTH` in constants is 20, not 25. The comment is inconsistent with the code.

**`tests/unit/content/inject.test.js`** (uses `loadInjectModules`):
- Tests `onVideoFound` attaches controller to video with `parentElement = null` but valid `parentNode`.
- Tests `onVideoFound` prefers `video.parentElement` over the passed `parent` argument.
- Tests `onVideoFound` handles video with both `parentElement = null` and `parentNode = null`, using the fallback parent argument.

**`tests/unit/utils/blacklist-regex.test.js`** (uses `loadMinimalModules`):
- Tests regex pattern without flags: `/(.+)youtube\.com(\/*)$/`.
- Tests regex pattern with flags: `/(.+)youtube\.com(\/*)$/gi` (case-insensitive).
- Tests simple string patterns.
- Tests mixed blacklist with strings and regexes.
- Tests malformed regex (`[unclosed`) is handled without throwing; valid pattern in same blacklist still matches.
- Tests empty/whitespace-only lines are ignored.

**`tests/unit/utils/recursive-shadow-dom.test.js`** (uses `loadCoreModules`):
- Tests `DomUtils.findShadowMedia` in single, 3-level, 5-level nested shadow roots.
- Tests finding multiple videos across different shadow roots.
- Tests audio elements found with `video,audio` selector.
- Tests `DomUtils.findMediaElements` uses recursive shadow search.
- Tests `MediaElementObserver.scanForMedia` finds video in 3-level nested shadow DOM.
- Tests complex nested custom element structure (`custom-player > video-playback > video`).
- Tests empty shadow roots return 0 results.
- Tests mixed regular DOM + shadow DOM.
- Tests multiple videos at different levels.
- Performance test: 10 structures × 4 levels deep in under 100ms.

### Integration Tests

**`tests/integration/module-integration.test.js`** (uses `loadCoreModules`):
- Tests all core modules load and register on `window.VSC`.
- Tests `siteHandlerManager.getCurrentHandler()` returns a handler and `getControllerPosition` returns valid positioning.
- Tests `VideoSpeedConfig.getKeyBinding('faster')` returns a number.
- Tests `VideoController` integrates with all dependencies — constructor succeeds and controller div exists.
- Tests `EventManager.setupEventListeners` and `cleanup` execute without errors.
- Tests `startHidden: false` controller has no `vsc-hidden` class and no `vsc-show` class; `startHidden: true` controller has `vsc-hidden` but not `vsc-show`.

### E2E Tests

**`tests/e2e/basic.e2e.js`** (Puppeteer, non-headless Chrome with extension loaded):
- Navigates to `tests/e2e/test-video.html` (local file with embedded Big Buck Bunny video).
- Waits for extension injection via `window.VideoSpeedExtension`, `window.videoSpeedExtension`, `.vsc-controller`, or `#vsc-test-indicator`.
- Tests video element is ready (`readyState >= 2 && duration > 0`).
- Tests `.vsc-controller` and its shadow `#controller` element are present.
- Tests initial speed is 1.0.
- Tests `.draggable` speed indicator text shows `1.x`.
- Tests `+` button increases speed above initial.
- Tests `−` button decreases speed below the increased value.
- Tests R key (rewind = advance per the test, but tests "speed changed from before") resets speed.
- Tests keyboard shortcut D (not in default bindings, likely a stale test from an older config) increases speed; S decreases.

Note: The `basic.e2e.js` test uses `chrome.runtime.getURL('/Applications/Google Chrome.app/...')` as a hardcoded `executablePath`, making it macOS-specific and not portable [`tests/e2e/e2e-utils.js:30-31`].

**`tests/e2e/display-toggle.e2e.js`**, **`tests/e2e/settings-injection.e2e.js`**, **`tests/e2e/youtube.e2e.js`**: Files listed in directory tree but not read in detail; their existence is confirmed from the file listing.

**`tests/e2e/run-e2e.js`**: Orchestrates E2E tests. **`tests/e2e/validate-extension.js`**: Validation script.

### Test Fixtures

**`tests/fixtures/test-page.html`**: Browser-runnable HTML page with buttons to run unit, DOM utils, and integration tests in-browser. Loads test modules via ES module `import`. Also includes a `<video>` element pointing to Big Buck Bunny.

---

## 8. Gaps & Observations

### 8.1 Duplicate CSS in Shadow DOM

`src/ui/shadow-dom.js` embeds the shadow controller CSS directly as a template string within the `createShadowDOM` function [`src/ui/shadow-dom.js:22-126`]. This CSS is byte-for-byte identical to `src/styles/shadow.css` [`src/styles/shadow.css:1-106`]. The `shadow.css` file is listed as a web-accessible resource in `manifest.json` but is never loaded dynamically by any source file at runtime — the embedded string in `shadow-dom.js` is what actually runs. The `shadow.css` file appears to be an unused artifact.

### 8.2 `module-loader.js` Not in Injection Chain

`src/module-loader.js` is a web-accessible resource and exports `window.defineModule` / `window.loadModule`, but is not included in the module list in `injector.js` and is not imported by any other module. Its last line references `window.VSC.logger.debug(...)` [`src/module-loader.js:72`], which would fail if executed before `logger.js` is loaded. The file is effectively dead code in the current boot sequence.

### 8.3 `VSC_TOGGLE_DISPLAY` Message Not Sent by Popup

`src/utils/constants.js:77` defines `MESSAGE_TYPES.TOGGLE_DISPLAY = 'VSC_TOGGLE_DISPLAY'`. The handler for this message exists in `inject.js:383-389`. However, `popup.js` does not define a button or path that sends `VSC_TOGGLE_DISPLAY`; it only sends `VSC_SET_SPEED`, `VSC_ADJUST_SPEED`, and `VSC_RESET_SPEED`. The toggle display functionality is thus unreachable from the popup.

### 8.4 `resetSpeed` Function Defined but Never Called in Popup

`popup.js` defines a `resetSpeed()` function [`src/ui/popup/popup.js:175-183`] that sends `VSC_RESET_SPEED`, but it is never called from any event listener in that file. The reset button's click handler calls `setSpeed(preferredSpeed)` instead, not `resetSpeed()`.

### 8.5 Wheel Handler Bypasses `setSpeed` (No Storage Persistence)

`ControlsManager.setupWheelHandler` sets `video.playbackRate = newSpeed` directly and updates the speed indicator text, but does not call `ActionHandler.setSpeed` or `config.save(...)`. Speed changes made via mouse wheel are therefore not persisted to `chrome.storage.sync` [`src/ui/controls.js:100-107`].

### 8.6 `EventManager.updateSpeedFromEvent` Directly Calls `chrome.storage.sync.set`

In addition to the normal `config.save` path, `EventManager.updateSpeedFromEvent` calls `chrome.storage.sync.set({ lastSpeed: speed })` directly with an availability check [`src/utils/event-manager.js:378-385`]. This bypasses `StorageManager` and saves only `lastSpeed`, not the full settings object. This creates a dual save path for `lastSpeed`.

### 8.7 `f-keys.test.js` — `loadMinimalModules` Called with Array Argument

`tests/unit/core/f-keys.test.js:11-18` calls `loadMinimalModules([...paths])`, but `loadMinimalModules` in `tests/helpers/module-loader.js:55-60` accepts no parameters and always imports the same four files. The array argument is silently ignored, meaning `action-handler.js` and `event-manager.js` are imported by the minimal loader but never through the intended path in this test, which could cause the modules to be loaded out of expected order depending on prior test state.

### 8.8 `CONTROLLER_SIZE_LIMITS` Comment/Code Mismatch

`src/utils/constants.js:93-98` defines `AUDIO_MIN_WIDTH: 20` and `AUDIO_MIN_HEIGHT: 20`. The test file `tests/unit/observers/audio-size-handling.test.js:15-19` comments "Below AUDIO_MIN_WIDTH (25)" and "Below AUDIO_MIN_HEIGHT (25)" for values of 20 and 15, respectively. The comments are wrong about the threshold values. Furthermore, `CONTROLLER_SIZE_LIMITS` constants appear to be unused in the actual runtime logic — `MediaElementObserver.shouldStartHidden` in `media-observer.js` does not reference `CONTROLLER_SIZE_LIMITS` at all.

### 8.9 Facebook Observer Does Not Attach Controllers

`FacebookHandler.setupFacebookObserver` detects new video elements via a `MutationObserver` and calls `this.onNewVideosDetected(videos)`. However, `onNewVideosDetected` only logs the detection (`window.VSC.logger.debug(...)`) and does not trigger controller attachment. The `VideoMutationObserver` (started separately) handles actual controller attachment; this Facebook-specific observer is redundant for that purpose or is incomplete.

### 8.10 `VideoSpeedConfig.initializeDefaultKeyBindings` — W Key Binding Uses Hardcoded `rewind`

`settings.js:181-193` adds two hardcoded bindings in `initializeDefaultKeyBindings`: W(87)=rewind/120s and T(84)=advance/120s. However, these same bindings are also in `DEFAULT_SETTINGS.keyBindings` (lines `src/utils/constants.js:45-46`). Since `initializeDefaultKeyBindings` is only called when `storage.keyBindings` is empty, and `DEFAULT_SETTINGS.keyBindings` is pre-populated, this migration path creates a slightly different set of bindings than `DEFAULT_SETTINGS` (it omits `display`, `mark`, and `jump` bindings that exist in `DEFAULT_SETTINGS`). In practice, settings load now uses `DEFAULT_SETTINGS.keyBindings` directly when storage is empty, making `initializeDefaultKeyBindings` a dead code path in the normal flow.

### 8.11 `inIframe` Check Uses `window.VSC.inIframe` but No Such Property Exists

`src/utils/event-manager.js:128` references `window.VSC.inIframe()`. However, `dom-utils.js` defines `window.VSC.DomUtils.inIframe` (as a property of `DomUtils`, not of `VSC` directly) [`src/utils/dom-utils.js:68-74`]. This would cause a runtime error ("window.VSC.inIframe is not a function") in iframe contexts.

### 8.12 Popup Icon Update Can Conflict with Background Icon Update

`popup.js:toggleEnabledUI` calls `chrome.action.setIcon(...)` directly [`src/ui/popup/popup.js:50-56`]. `background.js:updateIcon` also calls `chrome.action.setIcon(...)`. These two paths can overwrite each other: disabling the extension from the popup sets the disabled icon, but if a tab switch event fires in the background, `background.js:tabs.onActivated` re-evaluates the icon based on `tabControllers`, potentially overwriting the popup's disabled icon with the active/inactive icon (based on controller count, not on the `enabled` setting).

### 8.13 `StorageManager.waitForInjectedSettings` Uses a Polling Loop

`StorageManager.waitForInjectedSettings` polls `this._injectedSettings` every 10ms with `setTimeout` until the `VSC_USER_SETTINGS` event has fired [`src/core/storage-manager.js:69-81`]. If `injector.js` fails to dispatch `VSC_USER_SETTINGS` (e.g., due to a Chrome storage error), this loop runs indefinitely and `config.load()` never resolves, blocking extension initialization silently.

### 8.14 No Version Migration Logic for `speeds` Map

The `config.settings.speeds` object stores per-URL playback rates. Over time, this map can grow unboundedly (one entry per unique video URL encountered). There is no eviction, size limit, or cleanup mechanism. `chrome.storage.sync` has a 100KB quota; a very large `speeds` map could eventually exceed storage limits.

### 8.15 E2E Tests Are macOS-Only and Hardcode Chrome Path

`tests/e2e/e2e-utils.js:30-31` hardcodes `executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'`. This makes E2E tests non-functional on Linux or Windows CI environments without modification.

### 8.16 `inject.js` Creates a `#vsc-test-indicator` Hidden Div in All Environments

`src/content/inject.js:413-416` always appends a `<div id="vsc-test-indicator">` to `document.head` with `display: none`. This div serves only as an E2E test marker but is injected into every page in production.

### 8.17 `options.js` — `logLevel` Input Type is `select` Not `text`

`options.html:118-125` defines `#logLevel` as a `<select>` element, but `options.js:290` reads it as `parseInt(document.getElementById("logLevel").value)`, which works correctly since `select.value` returns the selected option's value string.

### 8.18 `DomUtils.findShadowMedia` and `getShadow` Both Do Recursive Shadow Traversal

Two similar recursive shadow DOM search functions exist: `DomUtils.getShadow(parent)` (returns all elements) and `DomUtils.findShadowMedia(root, selector)` (returns matching elements). `getShadow` is used by the Apple TV+ mutation observer path; `findShadowMedia` is used by `MediaElementObserver`. They have different traversal strategies and depth limits. `getShadow` uses a `WeakSet` for cycle detection; `findShadowMedia` does not.

### 8.19 `popup.js` — `resetSpeed()` Function References Wrong Action

The popup's `resetSpeed()` function sends `MessageTypes.RESET_SPEED` (`VSC_RESET_SPEED`) which is handled in `inject.js:375-381` by calling `actionHandler.resetSpeed(video, 1.0)`. This resets to 1.0x. But `popup.html:19` labels the button "1.0" and the `loadSettingsAndInitialize()` code sets `resetBtn.textContent = resetSpeed.toString()` where `resetSpeed` comes from the `fast` binding value (not necessarily 1.0). The button label is dynamic but clicking it sends a hardcoded 1.0 reset. However, the actual click handler calls `setSpeed(preferredSpeed)` not `resetSpeed()`, so the declared `resetSpeed()` is completely unused dead code.
