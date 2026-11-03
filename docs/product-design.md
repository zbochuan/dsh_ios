# Mobile product design

English | [中文](product-design.zh.md)

## Direction and evidence

The 2026-11-03 revisions first replaced the promotional welcome page with a quiet conversation client, after feedback that the earlier design looked unattractive and too AI-generated, with Claude and ChatGPT suggested as references. The later task-console revision on the same day makes the task, not the chat, the unit of the app: the phone is a pocket console for the agent running on the user's computer, and a conversation is one interaction inside a task. It follows wireframe boards reviewed in the project conversation (home, task, approval, drawer, pairing and settings); those boards are not stored in this repository. This page owns the resulting interaction intent and acceptance criteria. The [interactive HTML review](../design/product-review.html) still shows the earlier conversation-first design. It is a self-contained browser illustration with local state and no network requests; neither it nor the wireframes establish native iOS behavior.

The [reference study](../design/reference-study.json) records official US App Store metadata, 17 iPhone and two iPad screenshots viewed, evidence paths, hashes and ten observations. At retrieval, the listings reported Claude `1.261030.19` and ChatGPT `1.2026.293`; screenshot dates and correspondence to those binaries are unknown. These are static promotional images, not runtime evidence. Observe the application inside each composition, excluding advertising headlines, photography and gradients. No opened general-history drawer or animation behavior was established.

The reference study retains source URLs and hashes for selected evidence, not an archival screenshot bundle. Its local metadata and image paths point into ignored `build/references/` directories and are absent from a fresh clone. URLs support retrieval attempts and hashes allow comparison with retained bytes, but continued availability or identical future downloads is not guaranteed. The HTML review needs none of these downloads and contains no reference screenshot assets.

| Visible evidence | DSH decision | Limit |
|---|---|---|
| Small navigation controls around a large content area | Task list home with a menu button and new-task action; tasks open as full-screen detail | The drawer, per-computer grouping and iPad sidebar are DSH design choices, not established by the screenshots |
| Neutral user bubbles and unboxed assistant paragraphs | Give content the canvas; omit repeated assistant logos | Native type sizes, spacing and accessibility still need verification |
| One bottom composer with nearby controls | One multiline field with attach, model, permission and dictation controls; preserve keyboard safe area | Attach and direct speech recognition are placeholders until supported |
| Compact answer actions and structured file/approval objects | Copy, retry and fork near answers; diff and terminal cards; containers only for an actual pending request | Screenshot appearance proves neither execution nor approval acknowledgment |

[Application architecture](architecture.md) owns implemented capabilities and protocol boundaries; [Development and CI/CD](development.md) owns build and device evidence. The changes below describe source intent, not a completed native usability or accessibility evaluation. No user-study results or improvement percentages are claimed.

## Navigation and conversation

The assumed mobile job is to see what the agent on each computer is doing, answer anything waiting on the user, and start or steer a task while away from the desk. Execution, model credentials and project files stay on the computer. The current client shows example tasks locally and discovers real computers; it cannot yet list or continue a real Host session.

| Context | Primary content and action | Context and return path |
|---|---|---|
| First opening | A one-line purpose, a Connect computer card and one example task | No composer or new-task control before the example is opened |
| Home (Tasks) | "Waiting for you · N" cards first, then tasks grouped by computer with status, elapsed time and latest activity; a composer with computer, project and permission chips | The menu button or a leading-edge swipe opens the drawer; offline computers explain that tasks resume on reconnection |
| Drawer | Task search, All tasks, tasks grouped by computer and project with running and waiting dots; long press to rename, archive or delete | Footer rows open Computers and Settings; on iPad the drawer is the split-view sidebar |
| Task detail | Title with computer and project, messages, collapsed activity, diff and terminal cards, a running status line with Stop, and a composer with model and permission menus | Back returns to the list; the more menu offers new task, rename, archive and delete |
| Connect computer | QR viewfinder placeholder, explanation that code, files and keys stay on the computer, a copyable pairing command | Manual entry opens the existing Remote login; the example task is one tap away |
| Settings | Computers, notification preferences, new-task defaults and general (appearance, account, about) | Account keeps sign-out and connection recovery |

Opening the example loads the example tasks: one running, one waiting for approval, one completed with changes, one failed and one on an offline computer. The single example disclaimer lives in the completed example task; titles, footers and settings do not repeat demo warnings. New task reuses an untouched blank task; drafts are per task and survive navigation, panels and cancelled login. Storage remains in memory and does not survive process termination.

Assistant text stays on the canvas with inline Markdown, user text uses a neutral bubble, and activity collapses to one line such as "read 3 files · edited 2 · ran 1 command". Copy and fork sit below completed answers; retry appears on the latest answer only. Fork duplicates the conversation up to that message as a new task. Incoming text should not pull someone away from older content; preserve the return-to-latest action. Attach and direct dictation are visible placeholders that do not pretend to work.

## Mode and connection boundaries

Example tasks are labelled once, inside the example. Notification toggles are stored preferences only until the computer can deliver events; the pairing command `dsh pair` and QR scanning are proposals that ds-harness-remote does not yet provide. The phone offers three permission modes — ask every time, auto-edit files and plan mode — and never a mode that skips all approvals.

| State | Required behavior |
|---|---|
| Signed out | Explain the actual login destination and require a valid HTTPS origin, account and password |
| Loading or restoring | Show a progress state; prevent duplicate requests |
| Signed in, discovery failed | Keep the account context and show the failure with retry, never a successful empty-list message |
| Successful empty discovery | Explain matching account/service and enabling the computer plugin; allow refresh |
| Computer online/offline | Show only the server-reported state; invent no last-seen time, trusted badge or encrypted status |
| Login completed | Return to the computer list without resetting local tasks or drafts |

The current connection UI calls the existing login, restore, refresh and sign-out APIs; it does not simulate discovery. Full session support still requires Control/Relay, independent Host identity verification, Noise, capability negotiation, RPC and streams. Future sends and approval responses must distinguish submitted, acknowledged and unknown outcomes. No automatic replay of uncertain operations, and no conclusion that a computer task stopped merely because iOS entered the background.

## Approval in context

An approval belongs to its task. It surfaces as a card at the top of home, as a card in the task transcript and as a status line above the task composer; all open the same sheet. The sheet shows the action, the waiting task and time, the exact selectable command, the computer, the workspace and the agent's explanation, then Allow once, Reject and Reject with a note. Its footer shows and changes the task's permission mode. Explanations are not a safety guarantee. Do not offer permanent permission or swipe-to-approve.

Closing the sheet leaves a valid request unanswered. Resolving it consumes its identifier once, records the local choice, including any note, and displays a result in the same transcript; the wording never claims execution. Stopping a task or backgrounding the app cannot authorize an old request. An already open sheet checks both current identifier and waiting phase before enabling actions. Invalidated requests gain a brief transcript explanation while drafts stay intact. Real expiration events and Host acknowledgments remain future work.

## Native presentation and acceptance

Use system text styles, semantic controls, native navigation/sheets and a keyboard-aware composer. The palette is a white canvas with ink text and neutral surfaces; blue marks only running work and tappable links, amber marks only what is waiting for the user, green marks success and red failure. Commands and paths use a monospaced face; terminal output and the pairing screen use a dark surface. Avoid sparkle branding, gradients, decorative badges and numbered feature cards. Reuse no Claude/ChatGPT branding, screenshot pixels or unsupported capabilities.

| Near-term check | Acceptance |
|---|---|
| First screen and home | No promotional hero; connect and example entries only; waiting cards come first and tasks group by computer |
| Navigation and draft retention | Type a draft, create another task, go home, open panels and cancel login; the original draft remains in its task |
| Approval | Inspect command and location, close without deciding, then allow, reject or reject with a note; the request disappears once and a local result remains; stale requests cannot resolve |
| Discovery | Loading, error, empty, online and offline remain distinct; no error is converted into a fabricated device or usable remote task |
| Reading and input | Verify small iPhone and iPad, keyboard, long Chinese text, selectable commands, diff and terminal cards and return-to-latest |
| Accessibility and motion | Verify 44-point primary targets, largest accessibility text, VoiceOver labels for status and diff lines, light/dark contrast and Reduce Motion for the running indicator and drawer |

[UI tests](../AppUITests/DSHUITests.swift) cover send/stop, starting a task from home, draft retention across new tasks and cancelled login, allow, reject and reject-with-note, the home waiting card, background invalidation, the connect and pairing entries, the permission menu without bypass, fork, drawer search and largest accessibility text. [Conversation tests](../Packages/DSHCore/Tests/DSHCoreTests/ConversationTests.swift) and [task tests](../Packages/DSHCore/Tests/DSHCoreTests/TaskTests.swift) cover stale-request rejection, one-time consumption, notes, task status, grouping, search, retry, fork and time formatting. [Development and CI/CD](development.md) records completed builds, simulator results, device launch and the limits of browser and visual checks. Passing source tests or reachability assertions does not establish full native visual or accessibility acceptance; real Host interoperability remains unverified.
