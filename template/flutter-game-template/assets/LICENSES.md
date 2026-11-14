# Asset licenses

Every file under `assets/` (other than this file) MUST be listed here by its relative path with
its source and license. `scripts/check_asset_licenses.sh` fails CI otherwise.

| File | Source | License | Notes |
|------|--------|---------|-------|
| assets/ambience/before_sunrise.mp3 | Pixabay Sound Effects (pixabay.com/sound-effects), author dbsound, Pixabay file id 246785; converted to mono 64 kbps MP3 with a crossfaded loop point | Pixabay Content License (royalty-free, commercial use allowed; confirmed by owner) | background sound choice in Settings; page URL not recorded |
| assets/ambience/morning_birds.mp3 | Pixabay Sound Effects (pixabay.com/sound-effects), author nickype, Pixabay file id 146832; converted to mono 64 kbps MP3 with a crossfaded loop point | Pixabay Content License (royalty-free, commercial use allowed; confirmed by owner) | background sound choice in Settings; page URL not recorded |
| assets/ambience/heartbeat.mp3 | Pixabay Sound Effects (pixabay.com/sound-effects), author Dragon Studio, Pixabay file id 372448; converted to mono 64 kbps MP3 with a crossfaded loop point | Pixabay Content License (royalty-free, commercial use allowed; confirmed by owner) | background sound choice in Settings; page URL not recorded |
| assets/ambience/night.mp3 | Pixabay Sound Effects (pixabay.com/sound-effects), author NCPrime, Pixabay file id 291477; converted to mono 64 kbps MP3 with a crossfaded loop point | Pixabay Content License (royalty-free, commercial use allowed; confirmed by owner) | background sound choice in Settings; page URL not recorded |
| assets/ambience/bird.mp3 | Pixabay Sound Effects (pixabay.com/sound-effects), author Yuliana Yurukova, Pixabay file id 333090; converted to mono 64 kbps MP3 with a crossfaded loop point | Pixabay Content License (royalty-free, commercial use allowed; confirmed by owner) | background sound choice in Settings; page URL not recorded |
| assets/ambience/rain.mp3 | Synthesised noise by `game-factory/scripts/make_ambience.py` (no samples; fixed seed); mono 64 kbps MP3, 24 s, seamless loop | original (studio) | shop sound pack "Rain"; not yet reviewed by ear by the owner |
| assets/ambience/waves.mp3 | Synthesised noise by `game-factory/scripts/make_ambience.py` (no samples; fixed seed); mono 64 kbps MP3, 24 s, seamless loop | original (studio) | shop sound pack "Waves"; not yet reviewed by ear by the owner |
| assets/ambience/forest_wind.mp3 | Synthesised noise by `game-factory/scripts/make_ambience.py` (no samples; fixed seed); mono 64 kbps MP3, 24 s, seamless loop | original (studio) | shop sound pack "Forest wind"; not yet reviewed by ear by the owner |
| assets/ambience/fireplace.mp3 | Synthesised noise by `game-factory/scripts/make_ambience.py` (no samples; fixed seed); mono 64 kbps MP3, 24 s, seamless loop | original (studio) | shop sound pack "Fireplace"; not yet reviewed by ear by the owner |

| assets/content/index.json | Written by the studio (content CLI `build-index`); empty list in the template | original | built-in content index; every pack and asset the games add under assets/content/ is listed here too |

Format for an asset row: `| assets/sfx/pop.ogg | https://example.org/pop | CC0-1.0 | by Jane Doe |`

Art drawn in code (no files under `assets/`): the game tile art and the avatar shapes in `lib/ui/kit/ds_art.dart` (quick_quiz, door_runner, balloon_pop, tug_of_war, true_false, flash_review, equation_builder, cloze_fix, word_grid, memory_match, series_builder, word_builder, sort_bins, block_puzzle, blockfall, sudoku, solitaire, ball_sort, mahjong, merge, wingy, snake, bricks, stack, runner; fox, owl, bear, cat, frog, panda, rabbit, penguin) are original SVG shapes written by the studio. License: original.
