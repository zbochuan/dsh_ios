# Mobile product design

English | [中文](product-design.zh.md)

## Direction and evidence

The 2026-11-03 revision replaces the promotional welcome page with a quiet conversation client. The user's feedback was that the previous design looked unattractive and too AI-generated, with Claude and ChatGPT suggested as references. This page owns the revised interaction intent and acceptance criteria. The [interactive HTML review](../design/product-review.html) has been replaced with the current conversation, history, approval and discovery-entry design. It is a self-contained browser illustration with local state and no network requests; its layout and interactions do not establish native iOS behavior.

The [reference study](../design/reference-study.json) records official US App Store metadata, 17 iPhone and two iPad screenshots viewed, evidence paths, hashes and ten observations. At retrieval, the listings reported Claude `1.261030.19` and ChatGPT `1.2026.293`; screenshot dates and correspondence to those binaries are unknown. These are static promotional images, not runtime evidence. Observe the application inside each composition, excluding advertising headlines, photography and gradients. No opened general-history drawer or animation behavior was established.

The reference study retains source URLs and hashes for selected evidence, not an archival screenshot bundle. Its local metadata and image paths point into ignored `build/references/` directories and are absent from a fresh clone. URLs support retrieval attempts and hashes allow comparison with retained bytes, but continued availability or identical future downloads is not guaranteed. The HTML review needs none of these downloads and contains no reference screenshot assets.

| Visible evidence | DSH decision | Limit |
|---|---|---|
| Small navigation controls around a large conversation area | Inline title, history entry and new-conversation action; no marketing home screen | History sheet and iPad sidebar are DSH design choices, not established by the screenshots |
| Neutral user bubbles and unboxed assistant paragraphs | Give content the canvas; omit repeated assistant logos | Native type sizes, spacing and accessibility still need verification |
| One bottom composer with nearby controls | One multiline field and send/stop; preserve keyboard safe area | Omit model, voice and attachment controls until supported |
| Compact answer actions and structured file/approval objects | Keep copy near the answer; reserve containers for an actual pending request | Screenshot appearance proves neither execution nor approval acknowledgment |

[Application architecture](architecture.md) owns implemented capabilities and protocol boundaries; [Development and CI/CD](development.md) owns build and device evidence. The changes below describe source intent, not a completed native usability or accessibility evaluation. No user-study results or improvement percentages are claimed.

## Navigation and conversation

The assumed mobile job is to read a result, add direction or decide on a blocking operation while away from the computer. Execution, model credentials and project files stay on the computer. The current client can demonstrate conversation interactions locally and discover real computers; it cannot yet continue a real Host session.

| Context | Primary content and action | Context and return path |
|---|---|---|
| First opening | DSH title, one short invitation, Try local conversation and Sign in and discover computers | No active composer or new-conversation control before choosing the demo |
| Local conversation | Messages, one composer, new conversation | Compact Local demo title opens its explanation; history opens from the leading toolbar button |
| History | Search titles/workspaces, latest activity order, draft preview and pending state | Selecting a row returns to that conversation; Computers and Settings are secondary entries |
| iPad | History sidebar and conversation detail | Secondary destinations open in native sheets without replacing the selected conversation |
| Computers | Account source, real discovery results, retry or empty state | Device details identify server-reported status; no enabled remote project or chat control |
| Settings | Appearance, Remote account, demo exit/resume and about | Back or dismissal returns to the existing conversation |

Entering the demo opens a blank conversation immediately; examples remain in history, including one approval example. New conversation preserves the previous draft and reuses an untouched blank conversation when possible. Drafts are per conversation. Exiting the demo, opening connection screens and signing in preserve this launch's local history and drafts; re-entering resumes the selected conversation. Storage remains in memory and does not survive process termination. There is no destructive exit requiring a confirmation dialog.

Assistant text stays on the canvas, user text uses a restrained bubble, and copy belongs below each completed answer. Reasoning and activity default to collapsed. Pending approval remains visible within its conversation and can also be opened above the temporarily disabled send action. Incoming text should not pull someone away from older content; preserve the return-to-latest action. Do not add placeholder controls to resemble another product.

## Mode and connection boundaries

Use one compact persistent Local demo label in the conversation title. Its explanation states that responses are preset, choices are local and commands are not executed; it also explains the in-memory lifetime and provides exit/resume context. Avoid repeating full warnings in the transcript header, composer footer and every message. A short preset-response introduction and an approval outcome are contextual information.

| State | Required behavior |
|---|---|
| Signed out | Explain the actual login destination and require a valid HTTPS origin, account and password |
| Loading or restoring | Show a progress state; prevent duplicate requests |
| Signed in, discovery failed | Keep the account context and show the failure with retry, never a successful empty-list message |
| Successful empty discovery | Explain matching account/service and enabling the computer plugin; allow refresh |
| Computer online/offline | Show only the server-reported state; invent no last-seen time, trusted badge or encrypted status |
| Login completed | Dismiss login to its originating account/computer screen without resetting local conversations |

The current connection UI calls the existing login, restore, refresh and sign-out APIs; it does not simulate discovery. Full session support still requires Control/Relay, independent Host identity verification, Noise, capability negotiation, RPC and streams. Future sends and approval responses must distinguish submitted, acknowledged and unknown outcomes. No automatic replay of uncertain operations, and no conclusion that a computer task stopped merely because iOS entered the background.

## Approval in context

An approval belongs to its conversation, not to a separate primary tab. Its detail shows the computer, full workspace path, exact selectable command, reason and stated impact before allow-once and reject actions. The demo names its computer as an example. Scope is an explanation, not a safety guarantee; missing scope is explicit. Do not offer permanent permission or swipe-to-approve.

Closing the sheet leaves a valid request unanswered. Resolving it consumes its identifier once, records the local choice and displays a result in the same transcript; the wording never claims execution. Generation stop, demo exit or background invalidation cannot authorize an old request. An already open sheet checks both current identifier and waiting phase before enabling actions. Invalidated requests gain a brief transcript explanation while drafts stay intact. Real expiration events and Host acknowledgments remain future work.

## Native presentation and acceptance

Use system text styles, semantic controls, native navigation/sheets and a keyboard-aware composer. DeepSeek blue is a functional accent for focus, selection and sending. Keep neutral canvases, restrained bubbles and readable body text; avoid generic sparkle branding, gradients, decorative badges and numbered feature cards. Reuse no Claude/ChatGPT branding, screenshot pixels, model names or unsupported capabilities. The visual and motion passes must verify this direction in native screens; static references establish no animation prescription.

| Near-term check | Acceptance |
|---|---|
| First screen and chat | No promotional hero or feature stack; demo is explicit; one composer appears only after demo entry |
| Navigation and draft retention | Type a draft, create/select another conversation, exit/resume demo and cancel login; the original draft remains in its conversation |
| Approval | Inspect location/scope, close without deciding, then allow or reject; the request disappears once and a local result remains; stale/replaced requests cannot resolve |
| Discovery | Loading, error, empty, online and offline remain distinct; no error is converted into a fabricated device or usable remote chat |
| Reading and input | Verify small iPhone and iPad, keyboard, long Chinese text, selectable commands, history scrolling and return-to-latest |
| Accessibility and motion | Verify 44-point primary targets, largest accessibility text, VoiceOver order, light/dark contrast and Reduce Motion; no per-token whole-page animation |

[UI tests](../AppUITests/DSHUITests.swift) cover send/stop, history and demo-exit draft retention, both approval choices, closing an unanswered approval and the discovery-only entry. [Conversation tests](../Packages/DSHCore/Tests/DSHCoreTests/ConversationTests.swift) cover stale-request rejection, one-time consumption, invalidation feedback and retained drafts. [Development and CI/CD](development.md) records completed builds, simulator results, device launch and the limits of browser and visual checks. Passing source tests or reachability assertions does not establish full native visual or accessibility acceptance; real Host interoperability remains unverified.
