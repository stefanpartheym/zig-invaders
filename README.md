# zig-invaders

> My implementation of `Space Invaders` in [zig](https://ziglang.org/) using [raylib](https://github.com/Not-Nik/raylib-zig) and an [ECS](https://github.com/prime31/zig-ecs).

I'm working on this project as part of [The 20 Games Challange](https://20_games_challenge.gitlab.io/). Space Invaders is Challange/Game #3.

## Goals

- [x] Create a player ship that moves side to side.
- [ ] Create a few different types of alien invaders.
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

| Key                | Description |
| ------------------ | ----------- |
| `H`, `Arrow Left`  | Move left   |
| `L`, `Arrow Right` | Move right  |
| `Space`            | Shoot       |
