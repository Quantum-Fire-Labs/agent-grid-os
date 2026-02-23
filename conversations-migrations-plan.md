# Conversations to Chats Migration Plan

## Goal

Refactor messaging so `Chat` is a neutral thread model that supports:

- user + user
- user + agent
- user + agent + user (and larger groups)

Then remove the current agent-coupled conversation flow (`conversation.agent_id`, `Agents::Conversations::*` controllers).

## Current Problems (Why This Refactor Is Needed)

- `Conversation` is hard-coupled to `Agent` (`agent_id` required).
- Messaging routes/controllers are nested under `agents/:agent_id/...`.
- UI assumes every conversation has an agent.
- Agent reply logic lives on `Conversation`, making the model non-generic.
- Multi-agent conversations are not modeled cleanly.

## Target Architecture

### Models

- `Chat`
  - neutral thread model
  - `account_id` (required)
  - `title` (optional)
- `Participant`
  - polymorphic join table
  - `chat_id`
  - `participatable_type` (`User`, `Agent`)
  - `participatable_id`
- `Message`
  - polymorphic sender
  - `chat_id`
  - `sender_type` (`User`, `Agent`) (optional for system/tool messages)
  - `sender_id`
  - `content`
  - existing audio/tool payload fields preserved as needed
  - existing `role` semantics preserved (`system`, `tool`, `user`, etc.)

### Behavior Rules (V1)

- Do not model DM vs group as a core domain distinction.
- `group?` may exist as a convenience (`participants.count >= 3`) but should not drive core logic.
- `Chat` enforces minimum 2 participants.
- `Chat` belongs to an account (`account_id`).
- For V1, active chats require at least one user participant (agent-only runtime deferred).
- Authorization is participant-based for V1: only user participants can read/post.
- Account scoping: all chat participants must belong to the same account as the chat.

### Agent Reply Trigger Rules (V1)

- `0` agents in chat: never auto-reply.
- `1` agent in chat: always auto-reply to user-authored messages (no mention required).
- `2+` agents in chat: only reply when agent is explicitly tagged.
- If multiple agents are tagged, enqueue one reply per tagged agent.
- Agent/system/tool messages should not recursively trigger agent replies.
- Agent replies are triggered only from user-authored messages.

### Mention Rules (V1)

- User mentions use `@FirstnameLastname`
  - Example: `Jane Doe` -> `@JaneDoe`
- Agent mentions use `@AgentName` with spaces removed
  - Example: `Data Bot` -> `@DataBot`
- Mention matching is case-insensitive.
- Mention normalization strips spaces and punctuation.
  - Example: `R&D Bot` -> `@RDBot`
  - Example: `O'Neil` -> `@ONeil`
- Mentions are parsed on render in V1 (no mention metadata storage yet).
- Only agent mentions affect agent reply dispatch.
- User mentions are for rendering/UX only in V1.

## High-Level Strategy

Use a staged migration with a final cutover. Avoid a big-bang rewrite.

1. Introduce `Chat` and schema support for polymorphic participants and senders.
2. Backfill existing conversation data into chats.
3. Add generic `Chats::*` controllers/routes and UI paths.
4. Move agent reply logic into `Chat`/`Message` model APIs (with concerns/POROs as internals) and jobs.
5. Cut all messaging traffic to `Chat`.
6. Remove old conversation models/controllers/routes/tables.

## Phase 1: Schema Preparation (Additive, Safe)

### 1.0 Introduce `chats` table (new canonical thread)

Add `chats` table with:

- `account_id` (required)
- `title` (nullable)
- timestamps

### 1.1 Participants: Add polymorphic participant reference + `chat_id`

Add columns to `participants`:

- `chat_id` (new)
- `participatable_type`
- `participatable_id`

Keep existing `user_id` and `conversation_id` temporarily for backfill and compatibility.

Indexes:

- unique index on `[:chat_id, :participatable_type, :participatable_id]`
- index on `[:participatable_type, :participatable_id]`
- index on `chat_id`

### 1.2 Messages: Add polymorphic sender reference + `chat_id`

Add columns to `messages`:

- `chat_id` (new)
- `sender_type`
- `sender_id`

Keep existing `user_id` and `conversation_id` temporarily for backfill and compatibility.

Indexes:

- index on `[:sender_type, :sender_id]`
- index on `chat_id`

### 1.3 Conversations: Temporary decoupling for migration compatibility

Make `conversations.agent_id` nullable.

Model compatibility step:

- `belongs_to :agent` -> `belongs_to :agent, optional: true`

### 1.4 Optional compatibility metadata

If needed for migration safety, keep `conversations.kind` (`direct/group`) temporarily and stop using it in new code.

## Phase 2: Backfill Data

Production data exists and must be retained. Backfill is 1:1 (one `Conversation` → one `Chat`).

### 2.0 Backfill `Conversation` -> `Chat`

For each existing `Conversation`:

- create a `Chat`
- set `chat.account_id` from the conversation's account context (via agent/account)
- leave `title` blank initially (derive later if desired)
- persist mapping (`conversation_id` -> `chat_id`) for subsequent backfills

### 2.1 Backfill participants

For each existing `Participant` row:

- set `chat_id` from conversation-to-chat mapping
- set `participatable_type = "User"`
- set `participatable_id = user_id`

For each existing `Conversation` with `agent_id`:

- create a `Participant` row for the agent
  - `chat_id = mapped chat`
  - `participatable_type = "Agent"`
  - `participatable_id = conversation.agent_id`
- skip if already present (idempotent backfill)

### 2.2 Backfill message senders

For each existing `Message`:

- set `chat_id` from conversation-to-chat mapping
- if `user_id` present:
  - `sender_type = "User"`
  - `sender_id = user_id`
- else infer agent/system behavior:
  - assistant/tool messages from agent reply flow should map to the conversation's agent where appropriate
  - system messages may remain `sender_type/sender_id = nil` and continue using `role = "system"`

### 2.3 Data validation checks (required before cutover)

Add scripts/rake task or migration checks to confirm:

- every participant has polymorphic fields populated
- every non-system message has sender populated
- every migrated conversation with prior `agent_id` now has an agent participant
- every backfilled participant/message has `chat_id`
- no duplicate participants per chat

## Phase 3: Model Refactor

### 3.0 Introduce `Chat` model as canonical thread

Create `Chat` model and switch new code paths to use it.

- `belongs_to :account`
- `has_many :participants`
- `has_many :messages`
- optional `title`
- display name derived from `title` or participants

`Conversation` remains only as a migration compatibility model until cutover is complete.

### 3.1 Conversation model (temporary compatibility only)

Refactor `Conversation` only as needed to keep migration compatibility stable:

- avoid new feature work here
- deprecate usage in favor of `Chat`

### 3.2 Participant model

Refactor `Participant`:

- `belongs_to :chat`
- `belongs_to :participatable, polymorphic: true`
- keep legacy `user_id` / `conversation_id` accessors only temporarily if needed
- validations:
  - presence of polymorphic fields
  - uniqueness scoped to chat
  - same-account validation (via `User`/`Agent` vs `chat.account_id`)

### 3.3 Message model

Refactor `Message`:

- `belongs_to :chat`
- `belongs_to :sender, polymorphic: true, optional: true`
- preserve `role` for `system`/`tool` messages
- preserve `compacted_at` column unchanged — works with `Chat` as-is (used by memory recall seed and compaction)
- remove business logic assumptions that `user_id` is the only human sender path
- keep existing `role` semantics unchanged (`system`, `tool`, `user`, etc.)

### 3.4 Memory system references (mechanical renames)

Memory is agent-scoped (no `conversation_id` on `Memory`), so no schema changes needed. Update internal references from `conversation` to `chat`:

- `Agent::MemoryRecall#build_seed` — `conversation.messages` → `chat.messages`
- `Agent::Compaction.new(agent, conversation)` → `Compaction.new(agent, chat)`
- `Agent::Brain#respond` — pass `chat` to compaction and prompt builder
- `Agent::PromptBuilder#system_prompt` — accept `chat` instead of `conversation`

No logic changes required — these are all reference swaps.

## Phase 4: Extract Agent Logic from Conversation

Current agent reply behavior is embedded in `Conversation` and should move to the new `Chat` domain model.

Preferred shape (Rails conventions):

- thin controllers call intention-revealing model methods
- `Chat` / `Message` own messaging and reply-trigger behavior
- concerns organize chat traits (mentions, agent replying, streaming/broadcasting) where useful
- POROs may be used internally by concerns/models for parsing or selection logic
- shallow jobs delegate back to model methods

Likely responsibilities owned by `Chat`/`Message` APIs:

- identify agent participants in chat
- parse/resolve agent mentions from message content using shared mention normalization
- decide reply targets using multi-agent rules
- enqueue agent response jobs (`*_later` methods)
- generate/broadcast typing/streaming UI updates via Turbo Streams

V1 constraints:

- trigger only on user-authored messages
- no autonomous agent-to-agent runtime yet

## Phase 5: Controller and Routing Cutover

### 5.1 Add generic chat routes

Introduce generic routes (outside `agents` namespace):

- `resources :chats, only: [:index, :show, :create]`
- nested `messages`
- nested `participants`

`ChatsController` remains the UI surface and becomes the canonical controller namespace.

### 5.2 New generic messages controller

Move message creation/deletion logic out of `Agents::Conversations::MessagesController` into a generic controller that:

- loads chat by participant access
- creates messages through `Chat`/`Message` domain methods (not orchestration in controller)
- delegates agent reply triggering to model APIs
- relies on model/domain code to broadcast via Turbo Streams

### 5.3 Authorization

Retain participant-based access control:

- for V1: only user participants can read/post

Update existing concern(s) to stop depending on agent-nested lookups.

## Phase 6: UI Refactor (Sender/Participant-Driven)

Refactor chat UI to stop assuming every chat has a single agent.

### 6.1 Header and sidebar

- derive chat display name from `title` or participants
- remove mandatory single-agent profile/status assumptions
- render mixed participants (users + agents)

### 6.2 Message partials

Replace agent-centric rendering with sender-centric rendering:

- user sender avatar/name from `message.sender` (`User`)
- agent sender avatar/name from `message.sender` (`Agent`)
- system/tool messages use `role` (or system sender representation)

### 6.3 Composer behavior

- mention suggestions should include both user and agent participants
- agent reply behavior must not be inferred from old conversation kind semantics

## Phase 7: Multi-Agent Tagging Rules Implementation

Implement in `Chat`/`Message` domain behavior (not controller orchestration):

1. Gather agent participants in the chat.
2. If none: no agent response.
3. If one agent: always auto-reply to user-authored messages.
4. If multiple agents:
   - parse tags from the user message
   - match tags against agent participants only
   - enqueue only tagged agents
   - no tags => no agent response

### Tagging considerations

- Agent names should be unique per account (mention token source is display name).
- User mention token is `FirstnameLastname`.
- Agent mention token is `AgentName` with spaces removed.
- Strip spaces and punctuation for matching; match case-insensitively.
- Deduplicate tags to avoid duplicate replies.
- Ignore tags in agent-authored messages for reply dispatch.
- Centralize parser/normalization logic and reuse it in renderer + chat/message domain logic.
- V1 intentionally parses mentions on render (scope choice); mention persistence can be added later if needed.

## Phase 8: Cutover and Removal

After all traffic is flowing through `Chat` routes/controllers/UI:

Remove:

- `Conversation` model and conversation-named routes/controllers
- `Agents::ConversationsController`
- `Agents::Conversations::MessagesController`
- `Agents::Conversations::ParticipantsController`
- agent-nested conversation routes in `config/routes.rb`
- `Conversation#generate_agent_reply` and related model methods
- reliance on `conversations.agent_id`
- legacy `participants.user_id` and `messages.user_id` columns (after final verification)
- legacy `participants.conversation_id` and `messages.conversation_id` columns (after final verification)
- `conversations.kind` if unused
- `conversations.agent_id` if fully replaced by agent participants
- `conversations` table after migration validation

## Rollout / Risk Management

- Ship schema changes first (additive only).
- Backfill with idempotent scripts/tasks.
- Add logging around reply dispatch decisions during cutover.
- Run dual compatibility paths briefly if needed (legacy columns still present).
- Delete legacy columns/controllers only after production validation.
- Run the test suite after each migration/cutover phase and address failures caused by the new chat structure.

V1 scope constraint:

- No autonomous agent-to-agent chat execution yet (schema may support future expansion).

## Suggested PR Breakdown

1. Schema additions (`chats` table, `participants` polymorphic fields + `chat_id`, `messages` polymorphic sender + `chat_id`, nullable `conversations.agent_id`)
2. Backfill + validation task(s)
3. Model refactor (`Chat`, `Participant`, `Message`) + concerns/POROs for domain organization
4. Generic `Chats::*` controllers/routes + nested messages/participants
5. UI refactor to sender/participant-driven rendering
6. Multi-agent mention parsing/render + chat/message reply logic
7. Cutover + remove legacy conversation and agent conversation controllers/routes
8. Cleanup migrations (drop legacy columns / unused fields)

## Locked Decisions

- Rename `Conversation` to `Chat` (canonical thread model).
- Keep `Participant` and `Message` model names.
- `Chat` has required `account_id`.
- `Chat` has optional `title`.
- No core DM/group distinction; participant count may be used for presentation only.
- Enforce minimum 2 participants.
- Allow multiple agents in a chat.
- For V1, active chats require at least one user participant (no agent-only runtime yet).
- Single-agent chat: agent always replies to user-authored messages (no mention required).
- Multi-agent chat: only tagged agents reply; no tags means no agent reply.
- Agent replies are triggered only from user-authored messages in V1.
- Keep existing `Message.role` semantics unchanged.
- Mentions parsed on render in V1 (no mention metadata persistence).
- User mention token: `@FirstnameLastname` (spaces/punctuation removed for matching).
- Agent mention token: `@AgentName` with spaces/punctuation removed for matching.
- Mention matching is case-insensitive.
