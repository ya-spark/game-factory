# Judge bot (game package `game_judge_bot`, id `judge_bot`)

Status: BUILT 22 Nov 2026 (G-20, rewrite of True or false / `true_false`). Behaviour lives only in this file. The full design discussion and the owner questions are in `game-studio/docs/FEATURE-SPECS.md` section "G-20 Judge bot".

## Owner answers (22 Nov 2026, given to the builder)
1. Name **Judge bot** (id `judge_bot`, package `game_judge_bot`).
2. Younger level: a wrong answer shows the right verdict and moves on; no retry.
3. Older level: a right answer without an explanation moves on by itself after 1.2 s.
4. Light skill evidence: two right answers in a row make one pass (see Skill contract).
5. Content: a later queue item will author about 2 true/false statements per topic; nothing is written now.

## What it is
A toy judge robot (round body, lens eye, gavel arm, two shoulder lamps, streak bulbs on its hat; code art, no person, no animal) behind a desk. A ticket shows a claim; the child judges it TRUE (green lamp, tick) or FALSE (red lamp, cross). It plays `mcq` items (minPool 4, `accepts` only items that can become a claim). Free with ads, Game and Study mode. No title bar (the web bar says "Game: Judge bot"); exit (L), read aloud (Q) and pause (P) are 44 dp overlay buttons that print their key. It does not use `ChoiceGameScreen` (that stays for Balloon pop, Shooter, Tug of war, Cloze fix) but reuses the kit's `GameFrame`, `GameKeyboard`, `KeyHints`, `PauseOverlay`, `QuizSession`, `scoreForAnswer` and the host.

## Behaviour and feel
- **Start screen:** robot, a ticket-style line "I read a ticket. You say TRUE or FALSE. Press T or F, or tap a lamp.", two small example lamps, the topic and year, ONE big "Start (Enter / Space)", "How to play (H)".
- **Ticket:** the question (small, grey, derived claims only) and the claim (large, cream ticket, dark ink; younger 32 to 28 sp, older 28 to 18 sp, then it scrolls inside the ticket only). A top strip of the ticket keeps room for the stamp.
- **Claim model** (`Claim`, `buildClaim`): a native True/False item keeps its prompt and authored truth. Any other `mcq` item becomes a claim: the right option (true) or one wrong option that is never equal to a right one (false); a plain maths question ("What is 10 x 7?") shows "10 x 7 = 70?", anything else "The answer is: 70". With no usable distractor the true claim is used. Never the old run-on "question Answer: x" line.
- **Feedback matches the question (B-15):** `Claim` is dealt once (`ClaimDealer`) and the screen holds it until Next; the ticket, the stamp and the feedback always belong to the same ticket. `QuizSession.answer` is called once, at the pick or at time up, and advancing the session does not change what is shown. Feedback: true "True. 10 x 7 is 70."; false "False. The claim was 63. 10 x 7 is 70."; others quote the question ("The answer to "..." is ..."); native items "True. That statement is true.". Then the item's explanation, "+N stars" when earned.
- **Verdict beat:** the pick locks, the gavel taps (about 150 ms), the ticket is stamped with the RIGHT verdict (TRUE or FALSE, the stamp shows the answer, not the pick), the matching shoulder lamp lights (green right, red wrong, amber time up), the right lamp button glows and the other is dimmed and locked. A feedback panel (fixed height) shows the headline ("Right!", "Not this time.", "Time is up."), the verdict line and the reason; **Next (Enter / Space)** sits beside it ("See results" on the last ticket).
- **Balance:** per round the derived claims are 40 to 60 percent true and the same verdict never comes more than 3 times in a row (`planVerdicts`, injected `Random`, deterministic per seed); native items keep their authored truth.
- **Levels (`levelForSession`; Study never timed):** younger (years 0 to 2): no timer, no lives, no retry, bigger text. Older: 10 s a ticket (ring round the robot's eye, thin bar and clock "0:10" in the HUD; stopped while paused); time up buzzes (amber lamp), counts as wrong with `timedOut`. Hard (internal flag): 6 s, no label.
- **Streak and score:** `scoreForAnswer` (10, older +2 per streak step up to 5) plus, older level only, +2 and a "Fast +2" chip for a right answer in the first half of the timer. 5 streak bulbs on the hat and in the HUD (the 6th right starts a gold row); streak 3 and up: the robot nods; every 5: confetti pop; every 10: the head turns once. A wrong answer or time up resets the streak, the robot shrugs, no scolding text. HUD: "Ticket 3 of 8", "Streak N", "Score N", clock.
- **Pacing:** a right answer WITHOUT an explanation moves on after 1.2 s (older level, Game mode only; Enter, Space or Next skips at once). Never after a wrong answer, never with an explanation, never at the younger level or in Study, never with reduced motion or the screen reader on. Everything else waits for Next.
- **Results ("Case closed"):** score, stars (when the session awards them), "N of M judged right", best streak, up to 3 "Review these" cards (claim, right verdict, reason) for the missed tickets, and "Done (Enter / Space)" which leaves (the session cannot be replayed; the container offers the next round). `onScore` is called once, at the end.
- **Reduced motion** (host setting or system): no slide, gavel, nod, confetti, spin or auto-move; stamp, lamp and text change at once.

## Keyboard (B-01, B-09; the map has 1 to 4 and arrows, T F P L H are fixed shortcuts of this screen)
| Key | Start | Before the pick | After the pick | Results |
|---|---|---|---|---|
| Enter or Space | start | confirm the highlighted lamp (nothing if none); Space NEVER pauses | Next | Done |
| T or 1 | | TRUE | | |
| F or 2 | | FALSE | | |
| Left / Right | | highlight TRUE / FALSE (ring after the first key) | | |
| P | | pause | | |
| Esc | leave | pause (resumes when paused) | leave | leave |
| L | leave | leave | leave | leave |
| Q | | read the ticket | read the verdict | |
| H | how to play | how to play | | |
On the pause screen P, Esc, Enter or Space resume. The how-to dialog closes on Enter, Space or Esc. Every button prints its key: Start, Next, Done "(Enter / Space)"; the lamps carry a key cap T and F; exit L, pause P, read aloud Q; Resume "(P / Esc / Space)", Leave game "(L)"; a hint row ("T / 1 true", "F / 2 false", "P pause", "H how to play", "L leave") shows on windows 600 wide and 520 tall and up. Tab reaches the buttons.

## Layout (W7)
No page scroll at text 1.0 (the game fills the box it is given, the frame centres it, max content 960 dp). Portrait: HUD (44 dp, 56 at text over 1.2), robot and ticket (flexible), feedback panel (84 or 96 dp), lamps (each at least 72 dp tall, 140 dp wide; stacked under 300 dp column width or text scale over 1.3). Short landscape (height under 460 and wider than 1.3 times the height, 844 x 390): robot and ticket left, feedback and lamps right. Never reads `MediaQuery.size` for the play area (uses the box).

## Skill contract and question contract
Plays `mcq`; `QuizSession.answer(correct, timedOut, skillEvidence)` is called ONCE per ticket; `correct` = the child's verdict equals the claim's truth. **Light evidence (owner answer 4):** the item record, stars and coins follow `correct` as everywhere, but the skill evidence of a right answer is recorded only as the second or later right answer in a row (`countsAsSkillEvidence`); a wrong answer or time up always counts. `onAnswered` after every answer, `onScore` once at the end. No change to content or `minPool`.

## Screen reader
Ticket "Question: ... Claim: ... True or false?" (native: "Statement: ... True or false?"); lamps "True, key T" and "False, key F", after the pick "..., the right answer" / "..., not this one"; the verdict is a live region ("Right! True. 10 x 7 is 70. Explained. Streak 4."); the timer reads "Time left 0:07"; the robot is one image whose label follows the state ("Judge bot, waiting / thinking / happy / shrugging / buzzing, time is up"). Colour never carries the meaning alone (icons, the words TRUE and FALSE, the stamp text).

## Art
Code art (`lib/src/ui/judge_art.dart`): ink 0xFF2B2A4C outline, TRUE green 0xFF1E7B46 and FALSE red 0xFFC62F2F (white text at least 4.5:1, tested), amber 0xFFF2A93B for time up, ticket cream 0xFFFFF6DC with ink text (at least 7:1, tested). Nothing to list in `assets/LICENSES.md` (no asset files). A Figma prompt for later art is not written yet.

## Test map (`test/`)
- `judge_rules_test.dart` (pure Dart): levels (younger none, older 10 s, hard 6 s, study none, auto-move only older); claim from a native item (both truths), from `mcq` (true and false, distractor never a right option, question and rightAnswer kept, "10 x 7 = 70?" form, "The answer is:" form, feedback text, fallback to true, unusable items null); balance 40 to 60 percent and no run over 3 over many seeds, native truths kept, determinism per seed and ticket never changes; score, fast bonus, bulbs, light evidence; `renamedGameIds` true_false to judge_bot and the how-to entry; no Flutter import; colour contrast.
- `judge_bot_screens_test.dart`: Flow (first screen, one Start, no title; 4 tickets to results with score, judged right, best streak, stars; review cards); **B-15** (right, wrong and time up: ticket and feedback belong to the same question until Next); Input (T F 1 2, Left Right plus Enter and Space, Space never pauses, P and Esc pause and resume, Esc leaves after the pick, paused clock, H how to play closes on Enter, Space and Esc, key caps and key text on the buttons); Levels and pacing (younger no timer and no retry, older timer and time up, study no timer, auto-move after 1.2 s only for a right answer without explanation at the older level, never otherwise, score 12 14 16 18, light evidence on a real session); Reduced motion; Semantics; Layout (360x640, 390x844, 844x390, 1024x768, 1280x720, 1440x900, 1920x1080 less the 44 px web bar, text 1.0 and 1.5, younger and older: no overflow, no title, lamps at least 72 dp, exit and pause 44 dp; a long claim).
- `game_core/test/engine/quiz_session_evidence_test.dart`: `skillEvidence: false`.
- Browser check (Playwright Chromium on the real web build) and the look of the art, the feel of the gavel, nod and stamp, sound and read-aloud audio are not testable on the VM: the owner checks them in the browser.

## Not in this version
Native true/False content (a later queue item, about 2 statements per topic), sound, a Figma art prompt, Play again inside the game, apps (paused; they stay on `true_false` through `renamedGameIds` and the web build's `patch_renamed_games.py`).
