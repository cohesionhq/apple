# Product direction

What Cohesion's apps are for, as the maintainers have set it. This page
says what matters here; when the direction changes, this page follows.

**When a product question isn't answered here, ask the maintainers**
rather than guess. A design or copy detail inside an answered direction is
yours to decide; see "Decide, then report" in `CLAUDE.md`.

## The rules

| Topic | What it says for the apps |
| --- | --- |
| **Goal** | Cohesion is a self-hosted platform for power users, then developers, then home users. Data safety first: losing workspaces, tasks or documents is never okay, and the user is told what gets cleaned up. Polish over velocity: nothing is done until it's polished. Clients are capable, good platform citizens. Cohesion is open source and free, and nothing is gated: what needs Cohesion Cloud (pushes, Live Activities) works through Cloud and is never baked into the daemon. Copy is helpful, friendly, restrained in technical detail. |
| **Surface: the apps** | The native iPhone, iPad and Mac client: no web view, no data of its own. It matches the web on every feature that makes sense on mobile, up to a 13" iPad Pro with keyboard and trackpad, and adds what only a native app can (pushes, Live Activities, widgets, share extension). iPhone uses tabs, iPad a sidebar, and both get every new screen. iPad is first-class. Verification is by eye on a device. |
| **Parity with the web** | One row per web feature and its status in the apps (Yes, Partial, No, n/a), updated whenever either surface changes. See [parity-with-web.md](parity-with-web.md). |
| **Surface: the web UI** | The web is the full surface and gets every feature first. Its copy rules (web/README.md) are the apps' copy rules too; see [design.md](design.md). |
| **Agents** | One global model tier; cues at low, medium or high effort. Foreground agents change the workspace directly; jobs only propose unless granted. Proposals never expire. Memories: 20 per scope, the user can review and delete them. Teams are a roster plus shared memory. Model threads go after 14 idle days (the feed stays). |
| **Actors** | An actor is an agent on one of the user's devices, offered by a client that is online or offline. Statuses: working, needs attention, idle ("Done"), failed; a message restarts any session. Requests wait forever. Needs-you alerts are raised by the iOS app's Live Activity, not pushed by the daemon. Idle or failed, read sessions go after 7 days. |
| **Tasks** | Statuses: incomplete, completed, cancelled. A task is in one folder or the inbox; tags group across folders. Priority and size are optional; unsized tasks never match a size filter and sort last. Start and due dates are calendar days. Connector tasks are read-only. |
| **Clients and devices** | Paired means full power, no per-client scoping. Revoke removes the client, its sessions and its cloud push registrations. Clients don't work offline. Last write wins across devices. Protocol changes are additive so older clients keep working; the apps can't show an "update" message, since updating one takes a new binary. Cohesion Cloud gets no special treatment: the user enables the companion's permissions and hooks themselves. |

## Keeping in sync

When a change alters what the apps do for the user (a feature added,
removed or changed, a parity row moved, a rule above that turned out
wrong), say so in the report so the maintainers can update the direction.
Don't write plans into this repo.
