# Chat and the player list

Two small systems that both answer "who else is here": Roblox's own chat, extended to cross servers,
and the columns in the Tab player list.

## The Tab player list

`LeaderstatsService` publishes a `leaderstats` folder under each Player. That name is a convention
rather than an API — the CoreGui player list draws one column per child, in child order:

| column | class | why |
| --- | --- | --- |
| Rebirths | `IntValue` | numeric, so the list **sorts** on it |
| Money | `StringValue` | abbreviated through `Format.money`, e.g. `$2.04M` |

**Money is a string on purpose.** The player list cannot abbreviate: a `NumberValue` of 2040000 is
drawn as `2040000`, which is unreadable at column width and gets worse every rebirth. The cost is that
you cannot sort on it — and sorting on rebirths is the more honest ranking anyway, because money resets
to zero on every prestige, so a money column ranks whoever has *not* rebirthed recently.

Published from two places, and both are needed:

- `pushState`, the single funnel every money and prestige change already passes through, so the columns
  never lag the HUD.
- `onPlayerAdded`, because that function deliberately does **not** push state — the client pulls a
  snapshot over the Bridge handshake instead. Measured: without this, a player who joined and stood
  still had no `leaderstats` at all sixteen seconds later, because nothing had changed yet.

## Global chat

Roblox's chat is already global *within* a server: `RBXGeneral` reaches everyone here. What it cannot
do is cross the server boundary. `GlobalChatService` adds a second channel, **Global**, whose traffic
rides a `MessagingService` topic so every server sees it.

One path, whether the speaker is standing next to you or on another server:

1. the player types in the Global channel; `ShouldDeliverCallback` runs on the server
2. it returns **false** — nothing is delivered by the normal path, including to the sender
3. the text is published on the topic
4. every server, *this one included*, receives it
5. each server filters the text once per local recipient and fires `GlobalChat` to them
6. `GlobalChatController` draws it into the Global channel

Step 2 is what makes step 5 the only way a message is ever shown. There is no second code path to
drift, and no chance of a message appearing twice on the sending server.

### Things that will bite you

**Text filtering is not optional and not per-message.** What arrives over the topic is raw text typed
on a machine we know nothing about. Roblox requires text shown to a user to have been filtered *for
that user* — the same words are allowed between adults and blocked for a child — so `filterFor` runs
once per recipient and a failure drops the message for that recipient rather than falling back to the
raw string. This is also why `GlobalChat` is fired per player instead of broadcast: one filtered result
standing in for everybody is exactly what the filter exists to prevent.

**`ShouldDeliverCallback` runs once per recipient, not once per message.** With five people in the
server it fires five times for one message, so publishing is guarded by `MessageId` — without that,
one line is published five times and everyone sees it five times.

**`TextChannels` does not exist when server scripts run.** `CreateDefaultTextChannels` builds it
afterwards, so the service waits for it — and does that on a spawned thread, because `init.server`
starts the remaining services in sequence and an inline wait would hold all of them up.

**Channel tabs must be enabled** or a second channel is invisible: with tabs off the window shows one
conversation and there is no way to switch to another. `GlobalChatService.Start` sets
`ChannelTabsConfiguration.Enabled`, in code rather than in Studio, so the requirement travels with what
depends on it.

**In Studio the filter returns an empty string.** A local playtest is not connected to the filtering
service, so `GetChatForUserAsync` returns `""` for perfectly ordinary text and the strict path drops
every message. There is a Studio-only fallback to `GetNonChatStringForBroadcastAsync` so the feature
can be exercised locally; it is guarded on `RunService:IsStudio()` and must stay that way, because that
call is not filtered per user and is not acceptable on a live server.

**In Studio the topic only ever talks to itself.** `MessagingService` delivers between live servers of
a published place, and a Studio session is one server, so a message published there comes back there
and nowhere else. That exercises the whole path except the hop itself.

### Limits

Both are deliberately tighter than local chat, because a global line is read by every player in the
experience and the cost of spam multiplies by the server count:

| limit | value | why |
| --- | --- | --- |
| per player | one message / 3s | the sender is told, not silently ignored |
| whole server | 90 publishes / minute | the topic quota is ~`150 + 60 * players`; a loop elsewhere could otherwise throttle the topic for everyone |
| message length | 200 characters | the payload cap is 1 KB, and it is a reasonable length to read |

A refusal comes back on the same remote as a `System` string and is shown in the channel the player was
typing in — a message that vanishes with no explanation reads as broken chat, and they will just type
it again.

### Known wrinkle

The sender sees a **speech bubble** over their own head for a global message, without the `[GLOBAL]`
prefix. Bubble chat renders the outgoing message optimistically on the speaker's own client, before
delivery is refused; nobody else in the server sees that bubble. Harmless, but it is why a global line
can look local to the person who sent it.

### Verified

Measured live in a Studio session:

- `leaderstats` reads `Rebirths(IntValue)=0 | Money(StringValue)=$2.04M`
- channels are `RBXSystem, RBXGeneral, Global`, tabs enabled, the local player a member of Global
- `PublishAsync` on the topic came back to the same server
- a message typed into Global arrived as
  `<font color="#7FD4FF">[GLOBAL]</font> <font color="#25b9ff">[PET KEEPER]</font> <b>Harold</b>: hello from the global tab`
  — so the title tag keeps its rarity colour, exactly as `TitleController` does for local chat
- a second message inside the cooldown replied `GLOBAL CHAT: wait 3s before sending again`

The chat *window* itself could not be screenshotted: its log fades faster than the MCP screenshot
round-trip. The rendered string above was captured from `TextChannel.MessageReceived`, which is the
authoritative content.
