
# AGENTS.md – GLADIUS Project Instructions

## Purpose

This file defines how AI coding agents (e.g., Codex) should interpret, implement, and extend the GLADIUS project.

The goal is to ensure:

* Consistency with game design
* Data-driven architecture
* Deterministic combat behavior
* Clean, maintainable, extensible code

---

## Source of Truth (READ FIRST)

You MUST read and follow these documents before making changes:

1. `01_Gladius_Combat_Model.xlsx`
2. `02_Gladius_Unity_Data_Schema.docx`

Rules:

* The **combat spreadsheet defines ALL gameplay logic and balance**
* The **schema document defines ALL data structures and architecture**
* If code conflicts with these documents → **the documents are correct**
* Do NOT silently deviate from them

If something is unclear:

* Make the **smallest reasonable assumption**
* Document it clearly in your output

---

## Project Goals (Current Phase)

We are building a **vertical slice of combat only**.

Scope:

* 1v1 combat (RET_STARTER vs SEC_STARTER)
* Turn-based system
* Data-driven implementation
* Minimal UI (functional, not polished)

Out of scope:

* Management (Ludus)
* Multiplayer
* Monetization
* Meta progression

---

## Core Principles

### 1. Data-Driven Design (CRITICAL)

ALL gameplay values MUST come from data, NOT hardcoded logic.

This includes:

* Stats
* Damage formulas inputs
* Stamina costs
* Status durations
* Skill effects
* Equipment modifiers

Code should:

* Read definitions from structured data (JSON / ScriptableObjects)
* Never embed gameplay constants directly in logic

---

### 2. Separation of Concerns

You MUST separate:

* **Content Definitions**
  (static data: classes, skills, items, builds)

* **Runtime State**
  (HP, stamina, active effects, turn order)

* **Combat Resolution Logic**
  (hit chance, damage, status application)

* **AI Decision Logic**
  (what action to take)

* **Presentation/UI**
  (visuals only, no gameplay logic)

---

### 3. Deterministic Combat

Combat must be reproducible.

Requirements:

* Centralized RNG
* Ability to inject a seed
* No hidden randomness

---

### 4. Minimal, Extendable Architecture

* Build ONLY what is needed for the vertical slice
* BUT structure it so it can scale later
* Avoid overengineering (no premature ECS unless required)

---

### 5. Readability Over Cleverness

* Prefer simple, explicit code
* Avoid magic behavior
* Use clear naming aligned with the schema

---

## Implementation Rules

### Data

* Follow the schema document strictly
* Use IDs (e.g., `RET_STARTER`, `SEC_STARTER`)
* Keep data editable without touching code

### Combat Logic

* Implement formulas as defined in the spreadsheet
* Do NOT invent new mechanics unless necessary
* Clamp values where specified (e.g., hit chance)

### AI

* Use simple priority-based logic
* Must:

  * Avoid illegal actions
  * Respect stamina constraints
  * Attempt to win (basic competence)

### UI

* Keep minimal and functional
* Must display:

  * HP
  * Stamina
  * Status effects
  * Actions
  * Combat log

---

## What to Do When Something Is Missing

If the documents do not fully specify something:

1. Choose the simplest possible implementation
2. Stay consistent with existing systems
3. DO NOT expand scope
4. Document the assumption clearly

---

## What NOT to Do

* ❌ Do NOT hardcode combat values into logic
* ❌ Do NOT redesign systems
* ❌ Do NOT introduce new features outside scope
* ❌ Do NOT tightly couple systems
* ❌ Do NOT prioritize polish over correctness

---

## Output Expectations

When completing a task, you MUST:

1. Explain your implementation plan first
2. List ambiguities and assumptions
3. Implement the solution
4. Provide:

   * Files changed
   * Key decisions
   * Any deviations from documents
5. Keep explanations concise but clear

---

## Success Criteria (Vertical Slice)

The implementation is correct if:

* A full RET vs SEC fight can be played
* Combat resolves according to the spreadsheet
* All gameplay values come from data
* AI completes a match without errors
* The system is extendable to more classes/content

---

## Future Direction (Do NOT implement yet)

These will come later:

* Additional classes
* Skill trees
* Ludus management
* Meta progression
* Live events

---

## Final Instruction

When in doubt:

* Follow the documents
* Keep it simple
* Keep it data-driven
* Make it work end-to-end

---
