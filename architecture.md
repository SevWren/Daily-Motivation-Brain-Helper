# Program Architecture

```text
┌──────────────────────────────────────────────────────────────────────┐
│                              User / UI                               │
│  - Windows desktop interactions                                      │
│  - Select mode / options / output path                                │
└──────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         GUI Backend / Controller                     │
│                         src/core/gui_backend.py                      │
│  - Receives UI actions                                               │
│  - Validates inputs                                                  │
│  - Dispatches work by mode                                           │
│  - Orchestrates preview / generation / error handling                │
└──────────────────────────────────────────────────────────────────────┘
                 │                          │
                 │                          │
                 ▼                          ▼
┌──────────────────────────────┐   ┌───────────────────────────────────┐
│   Mode / Workflow Dispatch   │   │         Shared Utilities          │
│   (mode-specific logic)      │   │     src/utils/utils_image.py      │
│                              │   │  - Image helpers                  │
│  Examples inferred from      │   │  - Frame / resize / transform     │
│  repo structure:             │   │  - Common utility functions       │
│  - fade                      │   └───────────────────────────────────┘
│  - sequence                  │
│  - other generation modes    │
└──────────────────────────────┘
                 │
                 ▼
┌──────────────────────────────────────────────────────────────────────┐
│                         Logic / Generation Layer                     │
│                         src/logic/mod_*.py                           │
│  - Implements algorithm for each mode                                │
│  - Produces frames / assets / intermediate results                   │
│  - Example: src/logic/mod_fade.py                                   │
│    * generates fade sequences                                        │
│    * returns preview-ready frames                                    │
└──────────────────────────────────────────────────────────────────────┘
                                  │
                                  ▼
┌──────────────────────────────────────────────────────────────────────┐
│                          Image / Output Artifacts                    │
│  - Generated frames                                                  │
│  - Preview images                                                    │
│  - Final exported assets                                             │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                                Tests                                 │
│  test/unit/test_gui_backend_mode_dispatch.py                         │
│  - Verifies backend selects the correct mode handler                 │
│  - Guards dispatch behavior and error paths                          │
└──────────────────────────────────────────────────────────────────────┘
```

## High-Level Flow

```text
User action
  -> GUI backend
  -> mode dispatch
  -> logic module
  -> shared image utilities
  -> generated frames / preview / output
  -> UI updates or export result
```

## Notes

- `src/core/gui_backend.py` appears to be the main coordination point.
- `src/logic/mod_fade.py` suggests the app is organized by generation mode.
- `src/utils/utils_image.py` is the shared low-level image helper layer.
- Tests focus on backend dispatch behavior, which is a good boundary for regression coverage.
