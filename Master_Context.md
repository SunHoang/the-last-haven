# 🎮 THE LAST HAVEN - MASTER DESIGN & ARCHITECTURE DOCUMENT
**Target System:** Godot Engine 4.x
**Genre:** Base Building, Management, Monster Collection, RPG, Exploration
**Current Phase:** MVP (Minimum Viable Product) Implementation
**Document Purpose:** Single Source of Truth (SSOT) for AI Assistants and Developers. Overrides all previous GDD v0.1 and v0.2 drafts.

---

## 1. TECHNICAL ENVIRONMENT & ARCHITECTURE CONSTRAINTS
*   **Separation of Concerns:** Strict decoupling of Logic (GameState) and Presentation (UI). UI only sends `Commands` and listens to `EventBus`.
*   **Data-Driven:** All entities (Monsters, Items, Recipes, Nodes, Buildings) must be defined in JSON/CSV databases, not hardcoded.
*   **ID-Based Referencing:** Use unique identifiers (UUIDs for instances, `core:type:slug` for definitions). Never use direct memory references for saveable objects.
*   **Deterministic State:** Uses a central `GameClock` (Unix timestamp) and seeded RNG (`map_seed`, `combat_seed`) to ensure multiplayer/Save-Load consistency.
*   **State Serialization:** The entire game state must be serializable to a single JSON file.

---

## 2. REVISED MVP SCOPE & GAMEPLAY LOOP
*   **The Core Loop:** Farm/Quarry (Raw Materials) $\rightarrow$ Smelter/Workshop (Processed Goods & Contracts) $\rightarrow$ Active Exploration (Combat & Capture) $\rightarrow$ Base Expansion & Monster Ascension.
*   **Included in MVP:** 
    *   **Gacha System:** `Summoning Altar` is INCLUDED in MVP. Unlocks early. Uses `Soul Dust` + `Crystal` to craft `Summon Sigil`.
    *   **10 Elements:** Full implementation of elemental traits and matchups.
    *   **Early Game Fix:** Tutorial grants 1 Mossling + 1 Thornback extra for base labor. `Barkbeetle` is capturable. Added hidden Fire-element event in Region 1.

---

## 3. MONSTER PROGRESSION & INVENTORY
*   **Infinite Roster:** Habitat capacity limits are REMOVED. Monster inventory is infinite. Filter/Sort system manages the UI.
*   **Duplicate Mechanics:** Duplicates are kept as independent instances.
*   **Dismantle & Ascension (+1 to +20):**
    *   Players dismantle duplicates to get `Fragments`. (Common=10, Uncommon=15, Rare=25, Epic=40, Legendary=70, Mythical=120 fragments).
    *   Use Fragments to ascend the main monster (20 tiers).
    *   **Costs:** Scales non-linearly (e.g., +1 needs 4, +10 needs 16, +20 needs 79).
    *   **Milestones:** 
        *   `+5`: Utility Passive effect +25%.
        *   `+10`: Combat Passive effect +25% & Skill 1 multiplier +10%.
        *   `+15`: Skill 2 multiplier +10% & Start combat with +10 Energy.
        *   `+20`: Ascended Form & unlock 1 extra cross-element skill slot.

---

## 4. COMBAT MECHANICS & AI ALGORITHM
*   **Action Bar:** SPD dictates turns. Reaching 1000 triggers a turn.
*   **Energy System:** Starts at 30. Max 100. Normal Attack (+20). Skill 1 (-40). Skill 2 (-80). Taking damage (+10).
*   **Elemental Matchups:**
    *   *Base Circle:* Nature > Earth > Electric > Water > Fire > Nature (Damage $\times1.5$ / $\times0.5$).
    *   *Environment Triangle:* Ice > Nature/Wind. Wind > Earth/Water.
    *   *Duality:* Light $\leftrightarrow$ Dark (Mutual $\times1.5$ damage).
*   **Inherent Special Traits (Applied to all rarity tiers of these 4 elements):**
    *   `Aether`: Pierces 20% DEF. Deals $\times1.5$ damage specifically to Shields (Anti-Shield).
    *   `Light`: True Strike (Ignores Evasion). Deals +10% true damage if target is Buffed.
    *   `Dark`: Lifesteal (Heals for 10% of actual damage dealt. Excess becomes Shield).
    *   `Ice`: Action Delay (On-hit, directly reduces target's Action Bar by 5% - unresistable).
*   **AI Decision Tree (For Auto-Battle & Enemies):**
    1.  *State Check:* Skip turn if Stunned/Frozen. Target forced if Taunted.
    2.  *Skill Selection:* Use Skill 2 if Energy $\ge$ 80 $\rightarrow$ Skill 1 if Energy $\ge$ 40 $\rightarrow$ Normal Attack. (Healers only heal if an ally is < 50% HP).
    3.  *Targeting Logic:* 
        *   Attacker/Bruiser: Target lowest HP.
        *   Tank: Target highest ATK.
        *   Controller: Target Healer/Support, or highest SPD.
    4.  *Boss Telegraph:* At 100 Energy, Boss skips a turn to "Charge" an AoE. Player must Stun to interrupt or cast Shield to tank.

---

## 5. BASE ECONOMY & HYBRID STORAGE
*   **Hybrid Storage Zones (5-Zone Model):**
    1.  `Resource Storage`: 10,000 global capacity (Wood, Stone, Ores).
    2.  `Item Inventory`: 60 Slots (Contracts, Sigils). Max stack 99.
    3.  `Monster Material`: 40 Slots. Max stack 99 (Fragments).
    4.  `Relic Archive`: 30 Slots. Unstackable.
    5.  `Currency Wallet`: Infinite (Gold, Premium, Soul Dust).
*   **Smart Reservation System (Critical):**
    *   When a production queue (Manual) starts, ingredients are moved to `Input Reservation`.
    *   Full-Auto buildings calculate usable balance as: `Available = Total - Reserved`.
    *   Prevents automated systems (e.g., Smelters) from draining items needed for manual crafts or building upgrades.
*   **Offline Catch-up:**
    *   Calculates `offline_time` (Max 10 hours).
    *   Simulates production loops. Proportional refund if queues are cancelled mid-way.
    *   If storage fills up, overflow goes to `Pending Storage` (Unlimited in MVP, throws UI warning > 50 items).

---

## 6. ACTIVE EXPLORATION (DAG ALGORITHM)
*   **Topology:** Directed Acyclic Graph. 7 Layers total.
    *   Layer 0: Start (1 Node).
    *   Layer 1-4: Pathing (2-3 Nodes). No crisscrossing edges.
    *   Layer 5: Pre-Boss bottleneck (1-2 Nodes).
    *   Layer 6: Boss (1 Node).
*   **Node Allocation Constraints:**
    *   Layer 1 must strictly be `Combat` or `Resource`.
    *   Minimum 1 `Capture Spot` guaranteed per run (placed in Layer 2 or 3).
    *   `Camp` (Heal 30% HP) prioritizes Layer 3 or 4.
    *   No consecutive `Elite` nodes on the same path.
*   **Supply Economy:** 1 Step = 1 Supply. Pack holds 10 Supply. Shortest path to Boss is 6 steps. Extra supply pays for hidden events. Reaching 0 Supply forces a safe auto-retreat (keep all loot). Defeat keeps 50% loot.

---

## 7. DATA SERIALIZATION SCHEMA (game_state.json)
```json
{
  "metadata": {
    "schema_version": "1.0.0",
    "save_timestamp": 1731632100
  },
  "inventory": {
    "currencies": { "gold": 12400, "soul_dust": 45 },
    "resources": { "core:item:iron_ore": 300 },
    "reservations": {
      "res_01": { "item_id": "core:item:iron_ore", "amount": 30, "locked_by": "bldg_smelter_01" }
    }
  },
  "base": {
    "buildings": [
      {
        "instance_id": "bldg_smelter_01",
        "def_id": "core:building:smelter",
        "grid_x": 4,
        "grid_y": 5,
        "assigned_workers": ["mon_uuid_03"],
        "production_queue": { "status": "running", "recipe_id": "core:recipe:iron_ingot" }
      }
    ]
  },
  "monsters": [
    {
      "instance_id": "mon_uuid_01",
      "def_id": "core:species:mossling",
      "star": 3,
      "ascension_level": 5,
      "training_exp": 1250,
      "location_id": "bldg_farm_01"
    }
  ]
}
```