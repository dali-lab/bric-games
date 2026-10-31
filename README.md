# Threadbare

A story-driven, collaborative game where players don’t just explore a world—they co-create it. In Threadbare, players rebuild a world unraveling at the seams by recovering knowledge, crafting stories, and designing characters, quests, and cultures drawn from their own lives.

**Threadbare is currently in pre-alpha** and being used in select learning programs as a scaffolded learning experience. Learners create non-canon StoryQuests that live alongside the canon narrative. In the future, contributors will be able to contribute canon LoreQuests to the core narrative of Threadbare.

[Play the current pre-alpha release of Threadbare](https://play.threadbare.game/), or [play development versions](https://play.threadbare.game/branches/). New pre-alpha releases are published every 2–3 weeks.

<a href="https://flathub.org/apps/org.endlessaccess.threadbare">
  <img width="240" alt="Get it on Flathub" src="https://flathub.org/api/badge?locale=en"/>
</a>

## Playtesting Cider Quest (BRIC arcade)

This fork (`dali-lab/bric-games`) builds **Cider Quest**, the `apple_festival`
StoryQuest, for the BRIC arcade cabinet. Every web build here is the Cider-only
build. These links are public but unlisted, so share them only with the right
group.

| Tier | Who | Link | What it is |
|---|---|---|---|
| Internal | DALI team | <https://dali-lab.github.io/bric-games/branches/dali-lab/main/> | Latest `main`. Until the first `cider-v*` release, `main` is at the site root instead and this link is a 404. Each branch with an open PR also gets `/branches/dali-lab/<branch>/` (list: [`/branches/`](https://dali-lab.github.io/bric-games/branches/)). |
| Partner | BRIC (Ben, Chris) | <https://dali-lab.github.io/bric-games/prerelease/> | Latest `cider-v0.N.0-rc.M` pre-release, when it's newer than the latest stable release. Until there's a stable release, the pre-release is at the site root instead. |
| Wider test group | Classrooms, families | <https://dali-lab.github.io/bric-games/> | Latest stable `cider-v0.N.0` release. Before any release, this shows `main`. |

To play, use a gamepad (stick plus A/B/X) or the keyboard (arrows or WASD,
Space to talk, Shift to run, X to throw the hook, Esc to pause). Progress isn't
saved. After 90 seconds without input the game goes back to the title screen,
as it does on the cabinet.

### Jump to a level

Add a level's path after `#` to jump straight to it. These links use the site
root, which is `main` until the first release. After that, swap the base URL
for `/branches/dali-lab/main/` (or another tier) to test `main`. The level runs
in debug mode: nothing is saved, all abilities are on, and there's no idle
reset.

| Level | Link |
|---|---|
| 0 · Intro | [`#…/0_intro/apple_festival_intro`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/0_intro/apple_festival_intro) |
| 1 · Hub 1 | [`#…/1_hub_1/hub_1`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/1_hub_1/hub_1) |
| 2 · Stealth | [`#…/2_stealth/apple_festival_stealth`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/2_stealth/apple_festival_stealth) |
| 3 · Hub 2 | [`#…/3_hub_2/hub_2`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/3_hub_2/hub_2) |
| 4 · Cider press (apples) | [`#…/4_cider_press/apple_festival_cider_press`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/4_cider_press/apple_festival_cider_press) |
| 5 · Hub 3 | [`#…/5_hub_3/hub_3`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/5_hub_3/hub_3) |
| 6 · Mill gears | [`#…/6_mill_gears/mill_gears`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/6_mill_gears/mill_gears) |
| 7 · Hub 4 | [`#…/7_hub_4/hub_4`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/7_hub_4/hub_4) |
| 8 · Outro | [`#…/8_outro/apple_festival_outro`](https://dali-lab.github.io/bric-games/#quests/story_quests/apple_festival/8_outro/apple_festival_outro) |

Level folder and scene names are frozen because these links depend on them.
To rename one, follow the procedure in
[`docs/cider-quest-flow.md`](docs/cider-quest-flow.md), which also shows how
the levels connect.

### Cabinet build and releases

- **Cabinet controls** (cabinet builds only, see `scenes/globals/bric_cabinet/`):
  A talks, confirms and advances dialogue; B runs, throws the hook in the mill
  gears and goes back in menus; C pauses; the stick moves and aims. Hold
  A + B + C for 2 seconds to leave the game.
- **Releases:** publish a GitHub release with a `cider-v0.N.0` tag (tick
  "pre-release" for `-rc.M` tags). `release.yml` attaches
  `cider-quest-<ver>-web.zip`, the arcade package with its `bric-game.json`.
  Pages then moves the root or `/prerelease/` to it.
- **Dev feed:** every push to `main` refreshes the `dev-main` pre-release
  (`cider-quest-dev.zip`). The arcade's operator menu can play it. It never
  appears on the Pages tiers.

## Help Build Threadbare!

Threadbare is open source! We invite interested learners, educators, or game developers to follow along with its development and get involved where possible. The core team determines the overall game design and direction (ensuring it serves both players and learners), but anyone can join the community to find a place to help out:

- [Share playtest feedback](https://github.com/endlessm/threadbare/discussions/categories/playtest-feedback)
- [Ask and answer questions](https://github.com/endlessm/threadbare/discussions/categories/q-a)
- [Browse good first issues](https://github.com/endlessm/threadbare/issues?q=is%3Aissue%20state%3Aopen%20label%3A%22good%20first%20issue%22) to find something to tackle
- [Join our Discord](https://discord.gg/mNtzvvaFXF) to discuss the project with the team in real-time

Threadbare's code, comments, and development discussion are written in English.
If English is not your first language, don't worry: it's not the first language
for about half of the core team at Endless Access either, and we will be happy
to hear from you.

(We hope to add translations for the game itself in the medium term.)

## Getting the Source Code

Threadbare uses Git Large File Storage (LFS) to store large assets, such as
music and artwork. You must [install and configure Git
LFS](https://github.com/endlessm/threadbare/discussions/772) before you clone
the Threadbare repository.

## License

Threadbare's original source code in Threadbare itself is covered by [Mozilla
Public License Version 2.0](./COPYING).

Threadbare's original assets are covered by [Creative Commons
Attribution-ShareAlike 4.0 International](./LICENSES/CC-BY-SA-4.0.txt).

Threadbare includes third-party assets and addons that are covered by different
licenses. Using the [REUSE](https://reuse.software/) specification, all files in
the repository are labelled with their license in a machine-readable way,
through a combination of comments in the files themselves, supplementary
`.license` files, and [REUSE.toml](./REUSE.toml).

<!--
SPDX-FileCopyrightText: The Threadbare Authors
SPDX-License-Identifier: MPL-2.0
-->
