# Platform integrations

How the app and its three extensions hook into iOS, how the Mac app differs,
and what to touch when adding to each. `ARCHITECTURE.md` maps the files; this page is the wiring.
Changing an entitlement, a bundle id, an App Group or signing is a stop and
ask (`CLAUDE.md`).

## Targets and entitlements

| Target | Bundle id | Entitlements | Info.plist |
| --- | --- | --- | --- |
| `Cohesion` | `com.hellocohesion.app` | `aps-environment`, communication notifications, keychain group | `cohesionplus` URL scheme, Live Activities (and frequent updates), `INSendMessageIntent` |
| `CohesionShare` | `….share` | keychain group | share extension, one web URL |
| `CohesionWidgets` | `….widgets` | keychain group | WidgetKit extension |
| `CohesionNotificationService` | `….notificationservice` | none | notification service |
| `CohesionMac` | `….mac` | none beyond the sandbox's: outgoing connections, user-selected files read-only (build settings) | local network description, arbitrary loads as on iOS |

The keychain group is `$(AppIdentifierPrefix)com.hellocohesion.app` in
each iOS target's `.entitlements`. There is no App Group.

## The Mac

The Mac app has no extensions, pushes, Live Activities, widgets or controls:
those need the iOS targets and Cohesion Cloud's iOS Companion. It registers no URL
scheme, since nothing outside it opens one; `cohesion://` links in its text go
through `WindowModel.follow` as on iOS. Its pairing is its own, made with its
own setup code and listed as its own client; it uses the same keychain query
as iOS, which on the Mac is the login keychain, as `CohesionWebKit`'s is, with
no access group or entitlement.

## Pairing and the keychain

- `Pairing` (`CohesionCore`'s `Connection/Pairing.swift`) saves the setup code's address,
  the pinned server key and the client identity as one keychain item
  (service `Cohesion`, account `pairing`, after first unlock, this device
  only).
- `Pairing.read()` tells a pairing that isn't saved from a keychain it can't
  read, as before the first unlock, and never changes it. It blocks, and
  `AppModel` calls it on launch and each new window before it shows, so a
  launch with the device unlocked goes straight to what's paired. Only when
  it can't does a window show "Restoring your pairing…", never pairing, and
  read again when it becomes active and when the device unlocks. Only
  `AppModel.unpair()`, by the user or for a revoke, removes the pairing.
- The query names no access group, so it uses the first group in the
  target's `keychain-access-groups`. That is how the share extension and
  the widgets read the app's pairing with `Pairing.load()`.
- **A new extension that talks to cohesiond** needs the same keychain
  group, first in its list, and links `CohesionCore` (below). Adding the
  extension itself is a stop and ask.
- The notification service has no keychain access and never calls
  cohesiond; it works from the push payload alone.

## Files shared with extensions

The target folders are file-system-synchronized: a new file joins its own
folder's target. The share extension and the widgets link `CohesionCore`
(`Connection/`, `Models/`, `AppLink`) and `CohesionUI` (`AgentAvatar`,
`errorAlert`). Besides those, they compile from `Cohesion/`, listed in
`membershipExceptions` in `Cohesion.xcodeproj/project.pbxproj`
(`Exceptions for "Cohesion" folder in "CohesionShare"`, `… "CohesionWidgets"`
and `… "CohesionMac"`):

- Share, widgets and the Mac: `Assets.xcassets`.
- Widgets only: `LiveActivities/CohesionActivitiesAttributes.swift`.
- The Mac only: `Cohesion.icon`.

**When adding:** what an extension needs goes in `CohesionCore` or
`CohesionUI`, public. Neither can use `AppModel` or a screen, and neither links
`CohesionMarkdown`.

## Pushes

The app never talks to APNs through the daemon directly. Cohesion Cloud's
iOS Companion extension sends them; see its documentation for the
permissions and hooks the
user enables and the payloads.

- `Cohesion/Notifications/PushRegistration.swift` gives the APNs token and the
  Live Activity push-to-start token to cohesiond's iOS Companion extension
  (`callExtension` to `com.hellocohesion.ios-companion`'s `registerDevice`),
  which sends pushes through the relay itself. A Live Activity's own token
  goes to it as `registerLiveActivityToken`, and `liveActivityDismissed`
  tells it one ended. It registers again at launch, on return to the
  foreground and after pairing. Turning it off in Settings or unpairing
  calls `unregisterDevice`; revoking a client removes it on the daemon's
  side. A companion before version 9 (its `status` says) is refused with a
  message to update it.
- `Cohesion/Notifications/AppDelegate.swift` handles the token callbacks and a
  tap: a push with `agentId` sets `model.pendingLink = .agent(id)`, which
  the first active window takes (`takePendingLink()`). Its banner is
  hidden while any window shows that agent's chat (`shownAgentIDs`).
- `AGENT_MESSAGE`, the category of every agent push, carries a text field,
  `AppDelegate.replyAction`. What's typed goes to `agentId` from the
  background with `CohesionClient.deliver`, the chat's own send, within
  `replyDeadline`, and marks the agent read. A locked device asks to unlock
  first. A reply that fails posts a local notification whose `userInfo` holds
  the text (`failedReplyKey`), since nothing else outlives the app: its tap
  opens the chat with the text in the field (`AppModel.failedReplies`). It
  shows even over that agent's chat.
- Unpairing removes delivered notifications, whose agent ids belong to the
  server left.
- `CohesionNotificationService/` turns an agent push (`agentId`,
  `agentName`, `agentEmoji`, `agentColor`) into a communication
  notification with the agent's avatar as the `INPerson` image. It keeps
  its own copy of the agent colors and avatar sizing, since it shares no
  files; change it with `AgentColor` and `AgentAvatar`.

**When adding:** the payload is a contract with Cohesion Cloud. A new
key or kind of push is a cloud change first (stop and report). Validate
every payload value: it comes from outside.

## Live Activities

- One Live Activity, `ActivitiesLiveActivity` in `CohesionWidgets/`, for
  every cohesiond activity. The cloud starts it by push-to-start, updates
  it and ends it; the app never starts one.
- Its `CohesionActivitiesAttributes` (`Cohesion/LiveActivities/`) are compiled into
  the app and the widgets. The `///` on the type is the payload the cloud
  sends; every key may be missing and a value newer than the build falls
  back.
- The app watches `Activity.activityUpdates`, registers each activity's
  push token with the cloud using its `registrationCode`, and reports a
  dismissal.
- Tapping it opens the lead activity's `AppLink` (`widgetURL`).

**When adding:** `ContentState` changes alongside Cohesion Cloud only
(stop and report). Keep decoding lenient, as `Lenient` does. A new kind of
activity needs a `link` to open.

## Widgets

- `CohesionWidgets.swift` is the bundle: `AgentsWidget`, `TasksWidget`,
  `AgentAgendaWidget`, the Live Activity and the controls.
- Each widget loads the pairing, calls cohesiond itself and refreshes every
  15 minutes. The app reloads a widget by kind when what it shows changes
  (`RootView`): the agents (for the Agents and Agenda widgets, since an
  agenda's change posts a message, which changes its agent's row), or an
  invalidation of task lists, folders, tags or saved views.
- Taps open `AppLink` URLs (`widgetURL`, `Link`). A small widget has no `Link`,
  so the Tasks widget's rows there are buttons running `OpenTaskIntent`.
- `TasksWidget` is configured in Edit Widget (`TasksWidgetConfiguration`): a
  workspace or All Workspaces, then a view whose choices follow the workspace
  (`TasksViewEntityQuery`). The views every workspace has are
  `DashboardTaskFilter`'s, Upcoming, Inbox and All; a picked workspace adds its
  folders, tags and saved views. A view that's gone says so; it doesn't fall
  back to another. A locked keychain shows "Restoring your pairing…".
- `AgentAgendaWidget` is configured in Edit Widget (`AgentAgendaConfiguration`),
  picking an `AgentEntity` as the Chat with Agent control does. On the Home
  Screen it draws the agenda as the web's column beside the conversation does
  (a dot a step, then rows around the step the agent is on); on the Lock Screen
  (`accessoryRectangular`) the agent's name over that step. With no step left
  it says "All done", with no agenda "All clear"; an agent that's gone says so.
  A tap opens the agent's chat.
- The Tasks widget's checkbox runs `CompleteTaskIntent`, `.background` and held by the
  extension alone. The tap goes to `PendingCompletions`, in the extension's own
  `UserDefaults` (there is no App Group), and each reload sends what's waiting,
  so a tap away from the server isn't lost. A refusal drops it; a different
  pairing's are dropped unsent.

**When adding** a widget: add it to the bundle, open screens only through
`AppLink`, put what it needs in `CohesionCore` or `CohesionUI`, and reload its timeline from the app when its data
changes. Widget providers run off the main actor, so mark them
`nonisolated` (see `verify-change`'s known warnings).

## Controls

- Add Task, Chat with Agent and New Actor Session, in `CohesionWidgets/Controls.swift`,
  are buttons for Control Center, the Lock Screen and the Action Button: a
  system symbol and the accent tint, no other artwork. Each opens the app.
- What they run is in `CohesionCore`'s `Intents/AppIntents.swift`, iOS only,
  which is also what Shortcuts offers. The app's and the widgets'
  `AppIntentsPackage` types include it, so both bundles carry its metadata.
- Each intent is `.foreground` and pinned to the app
  (`allowedExecutionTargets = .main`), and sets `model.pendingLink` through
  `AppLinkOpener`, registered in `CohesionApp.init`, as a notification's tap
  does. Unpaired, the link waits behind the pairing screen until paired.
  They require an unlocked device (`.requiresAuthentication`), so a tap on the
  Lock Screen can't launch the app before it can read its pairing.
- The app must carry the intents as well as the extension: iOS refuses a
  foreground intent the extension alone holds ("openAppWhenRun is not
  supported in extensions"), and a background one returning `OpenURLIntent`
  with a `cohesionplus://` link doesn't open the app. linkd logs "metadata
  … did not match any imported or exported symbol" for `CohesionCoreIntents`
  at install; it is harmless.
- Chat with Agent's agent is picked in the control's settings
  (`AgentChatControlConfiguration`); with none it opens the agents.
  `AgentEntityQuery` lists agents with the shared pairing and gives up on the
  server after 3 seconds, so a chat still opens away from it.

**When adding** a control: an intent beside the others, opening an `AppLink`,
and the control in the bundle. An intent that works without the app is
`.background` and uses `Pairing.load()`, as `AgentsWidget` does.

## Share extension

- Activates for exactly one web URL (`NSExtensionActivationRule`).
- `ShareViewController` loads the URL and the pairing; `ShareToAgentView`
  shows the link, takes an optional note and picks an agent (the last one
  sent to, kept in the extension's own `UserDefaults`), then sends the link
  with `sendAgentMessage`, under the note if there is one, and closes. An
  agent has one conversation, so the link joins its chat. iOS doesn't let a
  share extension open its app, so the reply waits in the chat.
- The Mac has no share extension.

**When adding:** a new content type is a change to the activation rule
and the view. Shared text and URLs come from outside: validate them.

## Links (`AppLink`)

- `cohesionplus://` (registered in the iOS app's `Info.plist`) and
  `cohesion://` (written in Markdown) parse in one place, `AppLink.swift` in
  `CohesionCore`:
  `agent/<id>`, `actor-session/<id>`, `task/[<workspace>/]<id>`,
  `document/[<workspace>/]<id>`, `agents`, `new-task`, `new-actor-session`.
  Parsing is strict.
- URLs from outside arrive in `RootView`'s `.onOpenURL` and open in the
  window they're sent to; a notification tap arrives in `AppDelegate` as
  `model.pendingLink`, which one active window takes. Links tapped
  in the app go through `WindowModel.follow`, a shell's `OpenURLAction`.
- An agent or actor session navigates; a task or document opens in a sheet
  from `presentsLinkedItems()`. A target that's gone is a toast. `new-task`
  and `new-actor-session` open the window's own sheets (`windowSheets`).

**When adding** a target: a case in `AppLink` (parse and `url`), handled
in `RootView`'s `open(_:)` and in `WindowModel.follow`, and in
`LinkedItemSheet.swift` if it opens in a sheet. Follow "Links" in
`CLAUDE.md` for sheet versus navigation. The new path should match what
the daemon writes in `cohesion://` links.
