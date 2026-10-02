# Three-category manual combat contract

`CombatSkillCatalog.manual_actions(actor)` returns exactly three deeply read-only descriptors, ordered `martial`, `internal`, `lightness`, even for empty or untrained actors. Each descriptor has `id`, `category`, `name`, `target_team`, `cost`, `cooldown`, `effects`, `description`, `learned`, `reason`, and `learning_source`. A missing lesson yields a disabled `unlearned:<category>` placeholder with no effects and no target. The scheduler must reject `learned == false`; UI button visibility is not an authorization check.

Ordinary attacks happen automatically once per living actor per completed round and are absent here. Medicine and retreat are separate utilities. A zero-qi or untrained actor must still receive its automatic attack; it cannot hold up the round waiting for manual input. Costs are paid at accepted execution, never on queueing. Reject stale targets, insufficient qi, unlearned skills, or cooldown before paying a cost.

## Learning provenance

- Hero martial: retain the actual, validated `equipped_art`, all original `MartialCatalog` effects and IDs (`art:<art name>`), and normal proficiency. `PartyActorCatalog` must first validate current ownership. The skill catalog never chooses a fallback art for an invalid actor.
- Hero internal: `internal_unlocked: true` is a new explicit teaching receipt, not derived from level, school, rank, recruitment, or the lightness flag. Proposed minimal save integration: schema13 boolean `internal_unlocked`; schema1–12 migrate to false, fresh/reset false, missing/nonboolean schema13 field rejected. Add a free, separate “修习调息归元” choice with 岑远 at 南庭, available outside battle after level3 plus a school introduction. The existing training interaction is the destination; merely opening it or resting does not teach the art.
- Hero lightness: carry the existing earned `lightness_unlocked` boolean. 岑远's existing explicit 踏苇行 lesson teaches the same footwork's traversal and combat applications; explain both in the lesson, journal, and skill description. Existing legitimately learned traversal saves may use the new combat application. Internal learning remains independent.
- Companions: set detached actor `recruited: true` only after the existing actual Shen/Tang/Qin recruitment validation. Their authored techniques are part of their established training, described by `learning_source`, and inaccessible until explicitly recruited. No save-schema additions are needed for their existing training.

The catalog does not read or mutate HeroState, persist receipts, or grant progression. The actual lesson/save integration and construction of detached actors are the caller's responsibility.

## IDs and effects

All eight new skills target `self` and cost2 qi. Internal cooldown is3 complete subsequent rounds; lightness cooldown is2. Cooldown does not tick on another actor's action or on animation acknowledgement, and a newly executed skill skips the end of its casting round. At each later completed round, subtract one, clamped to zero. A skill executed in roundR with cooldown2 becomes ready at the start of roundR+3, after the full rounds R+1 and R+2. Queue validation and UI must use the same value.

| Actor | Internal ID and effect | Lightness ID and effect |
| --- | --- | --- |
| Hero | `internal:hero_tiaoxi`, 调息归元, `healing:16` | `lightness:hero_tawei`, 踏苇行, `next_hit_reduction:10` |
| Shen | `internal:shen_yangmai`, 温灯养脉, `healing:20` | `lightness:shen_liuying`, 流萤步, `next_hit_reduction:8` |
| Tang | `internal:tang_dingxi`, 定尺息, `healing:12, focus_bonus:6` | `lightness:tang_cunbu`, 寸步移锋, `next_hit_reduction:6, focus_bonus:8` |
| Qin | `internal:qin_guiyuan`, 归渡长息, `healing:18` | `lightness:qin_yanliu`, 沿流换位, `next_hit_reduction:12` |

- `healing` clamps to maxHP and never revives. A pure self-heal at full HP is unavailable; Tang's combined heal/focus still has an effect when HP is full, provided focus would improve.
- `next_hit_reduction` is a separate deterministic personal status. Apply after ordinary defense/vulnerability/guard and before ally barrier, clamp damage to zero; consume once on the next actual incoming strike even if all damage is absorbed. Refresh takes the higher amount, never adds. Unused reduction expires at the end of the current round. It is neither random evasion nor the `guard` flag, and cannot satisfy 问石门's guarded-heavy school trial.
- `focus_bonus` reuses martial focus semantics: next automatic basic receives the extra base damage; take the higher pending focus, never sum buffs; consume once on that basic. With no `focus_attack_multiplier`, only the stated flat bonus applies. Ordinary encounter mitigation still applies.
- None of these new abilities restore qi or create a cost-refund loop. Automatic basics retain the existing +2 qi (capped at maxQI), guaranteeing progress and a finite resource budget without manual attack or guard buttons.
- Existing martial effects retain their independent semantics, including hero school-trial art identity, actual positive healing, actual guard against an incoming heavy attack, and Shen's ally healing/Tang's weakening/Qin's ally barrier. Only martial uses contribute martial proficiency or school-trial provenance.

Focused definition checks: `godot --headless --path . --script tests/combat_skill_catalog_test.gd`. Scheduler integration must additionally test payment, per-round cooldown, real healing/reduction/focus, guard-versus-lightness trial distinction, downed actors, and nonblocking automatic basics.
