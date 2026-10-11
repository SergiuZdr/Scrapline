# Iteration 068 — Ink lines from the texture; mine bugs

**Status:** done -- waiting for the user's play-test
**Started:** 2026-10-12 · **Finished:** 2026-10-12
**Answers:** the user on 067: "add ink outlines drawn on the edges in the texture, and check -- I saw
several bugs with the mines in the game" (no specific bug named: found by reading and staging).

## Goal
Machines carry drawn ink lines on every sharp edge of their painted texture; mines stay on the board,
disappear when they go off, say what they do, and two enemies never promise the same mine.

## Scope
- In: `ink_toon.gdshader` (`comic_edge`), the combat scene's mine drawing and aim text, `IntentAI._mine_value`,
  a staged board `tools/frames/mines.json` (NOT content).
- Out: mine rules (still: goes off once under whatever starts a round on it).

## Steps
1. Find the mine bugs: read the sim, the AI and the scene; stage a board with mine layers on both sides.
2. Fix each; a verify_combat check for the AI one.
3. Texture-edge ink in the comic shader.
4. Checks, run bot, docs.

## Acceptance criteria
- [x] Mines stay drawn while anything plays (moves, the enemy volley) and vanish when they go off.
- [x] Aiming a Mine Layer says what it does (not "Nothing there is affected").
- [x] A second enemy mine layer does not plan a mine on a hex another is already mining (verify_combat).
- [x] Machine textures show ink lines on plate edges, bolts and rust borders (still shot).
- [x] verify_combat, verify_animation, verify_combat_input, verify_run_ui, verify_onboarding pass; run bot.

## Result
Mine bugs found:
1. **Mines vanished during every playback.** They were drawn as intent marks, which `_play_new_events`
   clears for every move and the whole enemy volley (the slag pools' bug of play-test 14). A mine came
   back only at the next refresh, and a mine going off at round start went off with nothing drawn.
   Now `_mine_views` keeps them as floor (with their danger ring), reconciled with the state on refresh
   and undo; MINE_LAID pops one in, MINE_BLEW removes it at once (with the hit's star).
2. **Aiming a mine said "Nothing there is affected."** It now says "Lays a mine (-N). It goes off under
   whatever STARTS the next round on this hex", and who stands on it.
3. **Two enemy mine layers planned a mine on the same hex.** The second cannot be laid (one per hex), so
   the enemy-fire list promised two mines and the second Sapper wasted its turn. `_mine_value` is 0 for a
   hex another of the side already mines this volley.
4. The blast at a mine used the glowing ring; it is the comic star and blast now.

Ink lines: the shader reads the texture's value gradient across 1.6 screen pixels (four samples at mip
bias 1.2) and inks it above 0.09, so lines keep their width at any distance. `shots/068_crop.png`
(067 vs 068), `shots/068_machine.png`, `shots/068_mines.png` (aim text; round 2 with the crew's mine still drawn).

Checks: verify_combat 357 (2 new), verify_animation 34, verify_combat_input 27, verify_run_ui 51,
verify_onboarding 39. Run bot, 150 runs: **54.7%** won, 0 illegal actions, 12.9 fights a run (052: 55.3%); Act 1 lost 10.7%, Act 2 20.9%, Act 3 22.6%.

## Decisions, lessons, open questions
- Anything that persists on the board is floor, never an intent mark (second time: pools in 14, mines now).
- Open: which mine bugs did the user see? If one is not among these four, it needs their description.

## Next
The user play-tests.
