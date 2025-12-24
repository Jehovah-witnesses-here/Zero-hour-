# ZERO-HOUR: Master Design & Build Document

---

## Overview
ZERO-HOUR is a 1:1 scale geolocation FPS for Android. It transforms your real neighborhood into a 3D zombie apocalypse, blending real-world data and strong privacy protections. The system is built around friend tagging, lobby/session privacy enforcement, and opt-in real-world maps.


## Core Game Modes

### Mode One: Survival (Arcade Mode)
- Inspiration: Modeled on Call of Duty Zombies (WAW through Black Ops 2): round-based team survival, points economy, wall-buy weapons, unlockable map areas, frantic wave defense.
- Map Types:
    1. Custom & AI-Generated:
        - Designed by you or Claude (the AI).
        - Safe for public/online play, no real identifying data.
    2. Private Real-World Town:
        - Only for private lobbies with all players as [Real-Life] tagged friends.
        - Map is a replica of the host/player's hometown.
        - No [Online] friends/randoms allowed.
- Privacy: Real map only available with [Real-Life] friends; mode set at lobby creation, cannot be changed mid-session.


### Mode Two: The Exclusion Zone (Sandbox/Persistent)
- Inspiration: Open-world, persistent play inspired by Minecraft and DayZ.
- Gameplay: Roam your town, scavenge for loot, claim buildings, set sleeping bag base, survive zombies (AI based on sound/light), persistent world changes.
- Map Types/Privacy: Real map and persistence only in all-[Real-Life] lobbies. Public/Online/matchmade play uses masked maps.


## Privacy System (Friend Tags & Firewall)
- Friend Tag Logic:
    - Each friend manually tagged: [Real-Life] (trusted) or [Online] (internet/matchmaking).
    - Tagging via friend list UI; editable anytime.
- Session/Lobby Enforcement:
    - Real-World Map Sessions: Only [Real-Life] friends. Invites/joins blocked for others; host migration to another [Real-Life] on disconnect.
    - Masked/Anonymized Sessions: If any [Online]/random, only anonymized/masked maps. No mid-session swap.


## Map Masking for Online/Matchmaking
- Building/house: No real numbers or unique features; generic unnumbered models.
- Business names: Generic/fake labels only.
- Streets: Random/codename names only.
- Landmarks/fog: Notable places fogged or generic.
- Comms: No sharing map pins/coordinates/custom info; only generic markers.
- Server-side masking: Never serves real data to online/strangers.
- Saves: Persistent worlds with online friends always masked, never real locations.


## Map Data & Usage
- Free map API, accurate as possible (suggest with open-source: OSM, etc.).
- No persistent storage of real location: only used at runtime.


## Lobby & Matchmaking Logic
- On lobby creation: host selects map type (Custom/AI vs. Real).
- System scans invitees:
    - All [Real-Life]: Real map enabled.
    - Any [Online]/random: Only masked map enabled.
- Session type locked on start.
- Join denied for [Online]/random in real map session.


## Host Migration
- If host disconnects, transfer to another [Real-Life] if possible, else end session.


## Player Experience & Communication
- UI: Shows map type/privacy at all times. Who is tagged what in friend list. Clear warnings when join/invites denied.
- Tags never appear live in matches—in pre-session UI only.


## Legal & Safety
- Users see privacy/safety notices before using real maps.
- Parental controls/min. age for real map feature.
- Stream overlays when private session, to discourage accidental data leaks.


## Technical/Pre-Dev Checklist & Action Items

### 1. Map Data Source
- Use free map API (OpenStreetMap or open-source); prioritize accuracy. Claude to suggest options.

### 2. Map Masking Logic
- Masked mode must use realistic layout but randomize/obfuscate all business, street, landmark names/models. Shops/landmarks fake but feel authentic.

### 3. Gameplay/AI on Real Maps (Mode One)
- Dead ends: Zombies handle AI pathfinding smartly.
- Zombies spawn in buildings.
- Full map is accessible, fog/out-of-bounds as needed.

### 4. Friend List/Tag UX
- Tag assigned at friend add/accept, editable any time. Not shown in live game/lobby, only in friend list UI.

### 5. Host Migration/Session State
- Open item for Claude: How best to migrate session, what state to transfer.

### 6. Session Join/Messaging
- Non-real friend/random join denied with message: "This session is for real friends only."

### 7. Data Storage
- Location and world data local only (no cloud sync by default).
- Open item: Claude may recommend best practice for backup/local saves.

### 8. Onboarding/User Education
- Open item: On first use, show users privacy/safety/real map notices and tutorial for friend tagging.

### 9. Technical Platform
- Open item: Claude/dev to choose min Android version, libraries, and multiplayer backend suitable for privacy, scale, and cost.


## Guiding Principle
"If a player is not tagged as a real-life friend, they will never see your real-world data. Zero exceptions. All real map data is ephemeral—used only at runtime for trusted sessions and never stored long-term."


## Summary Table
| Match Type                 | Who Can Join             | Map Type Available                |
|----------------------------|--------------------------|-----------------------------------|
| Private [Real-Life] only   | Only [Real-Life] friends | Real map or masked (host’s choice)|
| Online/public              | Any [Online]/random      | Masked map only                   |

## Ready for Claude
- All core logic and requirements are specified or marked open for smart defaults/input from AI/dev.
- Use this doc as a blueprint for building fundamentals and privacy-first systems.