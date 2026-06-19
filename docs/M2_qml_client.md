# M2 — Qt Quick / QML Client Shell (Detailed Plan)

*Milestone 2 from the roadmap. Migrate the desktop client from Qt Widgets to
Qt Quick/QML, keeping today's features, wired to the existing protocol, with a
dark theme. Design only — implementation in steps.*

---

## Goal

Replace the Widgets client with a Qt Quick one that has **feature parity** with
what we have now:

- Login / Register tabs (username, email, display name, password, confirm).
- A scrolling message list with history + live messages.
- A composer to send messages.
- Auth state switching (show auth screen → show chat on success).

…but built on QML so we can grow a modern, animated, Discord-like UI in later
milestones. **No new server work** — we reuse the existing `op`-envelope protocol
and the `ChatClient` networking logic.

**Definition of done:** the QML client connects, registers/logs in, shows history,
sends and receives messages live — same as the Widgets client — with a dark theme.

---

## Architecture

Clean split of responsibilities:

- **C++ owns** networking and data:
  - `ChatClient` (existing) — keep its socket + protocol logic; expose it to QML.
  - `MessageModel : QAbstractListModel` — the list of messages QML renders.
- **QML owns** presentation: windows, tabs, list view, composer, theme.

QML talks to C++ through:
- **Invokable methods** on `ChatClient` (`login`, `registerUser`, `sendMessage`).
- **Signals** from `ChatClient` (`authOk`, `authError`, `historyReceived`,
  `messageReceived`, `connected`, `disconnected`) handled in QML via `Connections`.
- A **model** exposed to the `ListView`.

```
   Main.qml (ApplicationWindow)
   ├── Loader / StackView
   │     ├── AuthView.qml      → chatClient.login()/registerUser()
   │     └── ChatView.qml      → ListView(model: messageModel) + composer
   └── Connections { target: chatClient }   // drives state + model
            │
            ▼  (C++)
   ChatClient (QObject, invokables + signals)   MessageModel (QAbstractListModel)
            │                                            ▲
            └───── messageReceived / historyReceived ────┘
```

---

## New / Changed Files

**Build & entry point**
- `CMakeLists.txt` (client) — switch to Qt Quick: use `qt_add_qml_module`, link
  `Qt6::Quick Qt6::Qml` (and keep `Qt6::Network`); drop `Qt6::Widgets`.
- `main.cpp` — `QGuiApplication` + `QQmlApplicationEngine`, register C++ types,
  load `Main.qml`.

**C++ types**
- `chatclient.{h,cpp}` — keep logic; add `Q_INVOKABLE` to `login`,
  `registerUser`, `sendMessage`, and `connectToServer`; register for QML.
- `messagemodel.{h,cpp}` — new `QAbstractListModel`:
  - Roles: `Username`, `Content`, `Timestamp`, `AuthorId`.
  - Methods: `appendMessage(QJsonObject)`, `loadHistory(QJsonArray)`, `clear()`.

**QML (in a `qml/` folder, bundled via the QML module)**
- `Main.qml` — `ApplicationWindow`; swaps `AuthView` ↔ `ChatView` on auth state.
- `AuthView.qml` — `TabBar` + `StackLayout` → `LoginForm` and `RegisterForm`
  (confirm-password checked in QML before calling `registerUser`).
- `ChatView.qml` — `ListView { model: messageModel }` with a message delegate,
  plus a composer `Row` (`TextField` + send `Button`).
- `Theme.qml` — a QML **singleton** with dark-theme colors, spacing, fonts.

**Removed from the build** (kept on disk until parity is confirmed)
- `mainwindow.{h,cpp}`, `mainwindow.ui` — replaced by QML.

---

## CMake (Qt Quick) Sketch

```cmake
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network)
qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(Chatties main.cpp chatclient.cpp messagemodel.cpp)

qt_add_qml_module(Chatties
    URI Chatties
    VERSION 1.0
    QML_FILES
        qml/Main.qml qml/AuthView.qml qml/ChatView.qml qml/Theme.qml
)

target_link_libraries(Chatties PRIVATE
    Qt6::Core Qt6::Gui Qt6::Qml Qt6::Quick Qt6::Network)
```

C++ types are exposed with the `QML_ELEMENT` macro (+ `#include <QtQml>`), so
`MessageModel` and `ChatClient` become creatable/usable from QML under the
`Chatties` URI. The single app instance can be shared via a context property set
in `main.cpp`.

---

## State & Data Flow

1. App starts → `ChatClient::connectToServer("127.0.0.1", 8080)`.
2. `AuthView` shown. User submits → `chatClient.login(...)` / `registerUser(...)`.
3. `Connections` on `chatClient`:
   - `authOk` → switch to `ChatView`.
   - `authError(reason)` → show the reason on the auth screen.
   - `historyReceived(arr)` → `messageModel.loadHistory(arr)`.
   - `messageReceived(obj)` → `messageModel.appendMessage(obj)`.
   - `disconnected` → back to `AuthView` with a notice.
4. Composer send → `chatClient.sendMessage(text)`; the server echoes it back to
   everyone (incl. us), so the model only ever appends from `messageReceived` —
   no local echo, same rule as today.

---

## Theming

- Use **Qt Quick Controls 2** with a custom dark palette via the `Theme.qml`
  singleton (background, surface, accent, text colors; base spacing; font sizes).
- Keep all colors/sizes in `Theme` so a light theme (and richer styling later) is
  a one-file change. This sets up the "nice GUI" direction from the roadmap.

---

## Build Order (within M2)

1. **Toolchain check:** switch CMake to Qt Quick; a minimal `Main.qml` window that
   just says "Chatties" — confirm it configures, builds, and runs.
2. **Expose `ChatClient`** to QML (`Q_INVOKABLE`, registration, context property);
   prove a button can call `connectToServer` / `login`.
3. **`MessageModel`** (QAbstractListModel) + expose to QML.
4. **`AuthView`** (login/register tabs) wired to `ChatClient`, with the
   confirm-password check.
5. **`ChatView`** (ListView + composer) bound to the model and `sendMessage`.
6. **State switching** (auth ↔ chat) via `Connections`.
7. **Dark theme** via `Theme.qml`.
8. **Parity test**, then delete the old Widgets files.

---

## Risks & Notes

- **C++ ↔ QML registration** is the main new concept: `QML_ELEMENT`, exposing a
  shared instance, and matching `QAbstractListModel` role names to delegate
  properties. Expect to iterate here.
- **Deployment:** `windeployqt` needs `--qmldir` so the QML plugins/modules ship;
  note this for packaging later.
- **Keep `ChatClient` protocol logic unchanged** — only add QML annotations. This
  guarantees we don't regress M1 behavior.
- **`QGuiApplication` vs `QApplication`:** QML uses `QGuiApplication` (no Widgets).
- Old Widgets files stay on disk until the QML client reaches parity, then remove
  them from the repo to avoid two clients.
