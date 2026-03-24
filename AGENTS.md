
# AGENTS.md – GLADIUS (Godot Project Instructions)

## Priority

This file defines the project rules for AI coding agents working on GLADIUS.

Always read this file before making changes.
These instructions override informal assumptions and should be treated as project policy.

---

## Project Purpose

GLADIUS is a **management-first gladiator game** with:

- strong roster / school management
- auto-resolved combat by default
- optional manual control later
- lightweight 2D presentation
- deterministic, data-driven combat simulation

This is **not** a player-action combat game first.
The main fantasy is:
- recruiting
- training
- equipping
- risking gladiators in uncertain fights
- watching outcomes unfold

---

## Source of Truth (READ FIRST)

Before doing any implementation work, you MUST read these documents in this order:

1. `docs/01_Gladius_Combat_Model.xlsx`
2. `docs/02_Gladius_Unity_Data_Schema.docx`

Important:
- The spreadsheet is the source of truth for combat rules, formulas, balance values, actions, statuses, and starter content.
- The schema document is the source of truth for data structure intent.
- However, the schema was originally written with Unity terminology. When implementing in Godot, convert it to a **Godot-friendly, engine-appropriate structure** without changing the game design intent.

If code conflicts with the documents:
- the documents win

If a document uses Unity-specific language:
- adapt it to Godot cleanly
- preserve behavior and data model intent
- document the adaptation clearly

If anything is unclear:
- make the smallest reasonable assumption
- document it

---

## Current Development Goal

We are building a **Godot vertical slice** for:

- deterministic 1v1 combat simulation
- `RET_STARTER` vs `SEC_STARTER`
- auto-combat first
- simple combat viewer UI
- minimal pre-fight setup only if needed

Do NOT build the full management layer yet unless explicitly requested.

---

## Core Design Rules

### 1. Data-Driven Design (Critical)

All gameplay values must come from external data, not hardcoded logic.

This includes:
- stats
- action costs
- cooldowns
- status durations
- equipment modifiers
- AI profile parameters
- initiative coefficients
- hit chance coefficients
- damage coefficients
- crit values
- stamina rules

Code may implement formulas, but formula inputs must come from data.

---

### 2. Engine-Neutral Game Logic

Keep gameplay logic as engine-agnostic as practical.

Separate clearly:
- content definitions
- runtime combat state
- combat systems
- AI decision logic
- presentation/UI
- persistence/save data

Do not mix Godot node behavior with core simulation rules.

---

### 3. Godot Architecture Rules

Use Godot in a lightweight way.

Prefer:
- scenes for presentation/composition
- scripts for behavior
- Resources and/or JSON-backed content definitions where appropriate
- Autoloads only for true app-level services

Avoid:
- putting gameplay logic everywhere in scene nodes
- giant all-purpose scenes
- tightly coupling UI to combat rules
- overengineering

---

### 4. Auto-Combat First

Combat should be implemented as:
- simulation first
- viewer second
- optional manual intervention later

Do NOT design the first playable slice around direct player control of a gladiator.

The player’s role in the first slice is primarily:
- launch or inspect a match
- observe combat state
- optionally choose limited tactical setup if requested later

---

### 5. Deterministic Combat

Combat must be reproducible from a seed.

Requirements:
- centralized RNG
- no hidden randomness
- no direct random calls scattered through systems
- same seed = same combat sequence

---

### 6. Minimal, Scalable Structure

Build only what is needed now, but organize the code so later additions are easy:
- management layer
- more classes
- injuries
- economy
- events
- optional manual control

---

## Mandatory Separation of Responsibilities

### Content Definitions
Static data only:
- classes
- builds
- equipment
- skills
- statuses
- AI profiles
- combat rules
- encounter definitions

### Runtime State
Mutable combat/session state only:
- current HP
- current stamina
- cooldowns
- temporary statuses
- initiative order
- turn count
- combat log entries

### Systems
Pure gameplay rule execution:
- hit chance
- damage
- stamina
- status application / expiry
- turn sequencing
- victory resolution

### AI
Legal action choice only.
No direct mutation of combat state outside proper combat flow.

### UI / Scenes
Display and input wiring only.
UI should not own gameplay rules.

---

## Data Rules

Preferred approach:
- modular content files, not one giant monolithic file

Expected content files:
- `combat_rules.json`
- `classes.json`
- `builds.json`
- `equipment.json`
- `skills.json`
- `status_effects.json`
- `ai_profiles.json`
- `encounters.json`

If Godot Resources are used, keep them modular and organized.
JSON is acceptable and encouraged for designer-editable balance data.

---

## Implementation Rules

### Combat Logic
- formulas belong in systems
- tuning values belong in data
- no gameplay constants hardcoded in UI or scene scripts

### Actions
Implement only the actions needed for the requested slice.
Do not invent extra mechanics unless needed to satisfy the spreadsheet.

### AI
Use simple, readable, rule-based AI.
AI must:
- choose only legal actions
- respect stamina/cooldowns/statuses
- complete a full fight without soft-locking

### Logging
Combat must expose readable log entries for debugging and later UX.

---

## Godot-Specific Preferences

Prefer a folder layout that keeps:
- scenes separate from scripts
- simulation separate from presentation
- data easy to inspect/edit
- tests separate from runtime code

Use small scenes and clear node trees.
Use signals/events where appropriate, but do not hide core simulation flow inside signal spaghetti.

---

## What NOT to Do

- Do NOT make combat manual-first
- Do NOT hardcode spreadsheet values into scripts
- Do NOT put combat formulas in UI scripts
- Do NOT make one giant “manager” script own everything
- Do NOT tightly couple scene nodes to runtime simulation objects
- Do NOT expand scope into full management systems yet
- Do NOT redesign the game away from management-first auto-combat

---

## Output Expectations for Every Task

When completing a task, always provide:

1. implementation plan
2. ambiguities found
3. assumptions made
4. files changed
5. brief summary of what was implemented
6. remaining gaps / next recommended step

Do not stop after planning unless explicitly asked.

---

## Success Criteria for the First Vertical Slice

The first Godot slice is correct if:
- a full `RET_STARTER` vs `SEC_STARTER` fight can run end-to-end
- combat is deterministic from a seed
- core combat values come from external data
- UI displays the fight clearly
- AI behaves legally
- architecture remains clean and extendable

---

## Future Direction (Do Not Implement Yet)

Later systems may include:
- gladiator school management
- economy
- recruitment
- training
- injuries and death persistence
- event chains
- optional manual tactical interventions

These are future phases unless explicitly requested.

---

## Final Rule

When in doubt:
- follow the docs
- preserve design intent
- keep systems data-driven
- keep Godot usage lightweight
- favor simple, maintainable code
