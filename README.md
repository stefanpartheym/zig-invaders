# zig-invaders

> My implementation of `Space Invaders` in [zig](https://ziglang.org/) using [raylib](https://github.com/Not-Nik/raylib-zig) and an [ECS](https://github.com/prime31/zig-ecs).

I'm working on this project as part of [The 20 Games Challange](https://20_games_challenge.gitlab.io/). Space Invaders is [Challange #3](https://20_games_challenge.gitlab.io/challenge/#3).

## Goals

- [x] Create a player ship that moves side to side.
- [x] Create a few different types of alien invaders.
  - [x] Enemies will move together in a grid. They cross the screen horizontally before dropping vertically and reversing their direction.
- [x] Add the ability for the player ship to fire rockets that travel up the screen.
- [x] Add bombs/bullets that the enemies drop. The player’s rockets can destroy enemy bullets.
- [x] Make sure that the player’s bullets will destroy invaders, and the invader bullets will destroy the player.
- [ ] Add a mothership that will cross the screen periodically. Destroying it will result in bonus points.
- [x] Add a UI that tracks the player score and lives left. The player starts with three lives.

## Running the game

```sh
zig build run
```

## Controls

| Key                | Description         |
| ------------------ | ------------------- |
| `H`, `Arrow Left`  | Move left           |
| `L`, `Arrow Right` | Move right          |
| `Space`            | Shoot               |
| `Enter`            | Start/pause/resume  |
| `F1`               | Toggle debug mode   |
| `F2`               | Toggle sounds/music |

## Assets

List of all assets used in this game:

| File                         | Source/Author                                                                                                                              |
| ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `assets/soundtrack.wav`      | [stefanpartheym](https://github.com/stefanpartheym) in [Ardour](https://ardour.org/) with [OB-Xd](https://www.discodsp.com/obxd/)          |
| `assets/explosion.wav`       | [stefanpartheym](https://github.com/stefanpartheym) in [Ardour](https://ardour.org/) with [Surge XT](https://surge-synthesizer.github.io/) |
| `assets/explosion-short.wav` | [stefanpartheym](https://github.com/stefanpartheym) in [Ardour](https://ardour.org/) with [Surge XT](https://surge-synthesizer.github.io/) |
| `assets/impact.wav`          | [stefanpartheym](https://github.com/stefanpartheym) in [Ardour](https://ardour.org/) with [Surge XT](https://surge-synthesizer.github.io/) |
| `assets/win.wav`             | [stefanpartheym](https://github.com/stefanpartheym) in [Ardour](https://ardour.org/) with [Surge XT](https://surge-synthesizer.github.io/) |
| `assets/loose.wav`           | [stefanpartheym](https://github.com/stefanpartheym) in [Ardour](https://ardour.org/) with [Surge XT](https://surge-synthesizer.github.io/) |
| `assets/gameover.wav`        | [stefanpartheym](https://github.com/stefanpartheym) in [Ardour](https://ardour.org/) with [Surge XT](https://surge-synthesizer.github.io/) |
| `assets/player.png`          | [stefanpartheym](https://github.com/stefanpartheym) in GIMP                                                                                |
| `assets/invaders.png`        | [Alfalfamire on OpenGameArt.org](https://opengameart.org/content/8-bit-alien-assets)                                                       |
| `assets/explosion.png`       | [Sogomn on OpenGameArt.org](https://opengameart.org/content/explosion-3)                                                                   |
