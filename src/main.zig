const std = @import("std");
const entt = @import("entt");
const rl = @import("raylib");

const PlatformAgnosticAllocator = @import("paa.zig");
const Application = @import("application.zig").Application;
const ApplicationConfig = @import("application.zig").ApplicationConfig;
const comp = @import("components.zig");
const State = @import("state.zig");

pub fn main() !void {
    var paa = PlatformAgnosticAllocator.init();
    defer paa.deinit();

    var app = Application.init(
        paa.allocator(),
        .{
            .title = "zig-invaders",
            .display = .{
                .width = 800,
                .height = 600,
                .target_fps = 60,
                .high_dpi = true,
            },
        },
    );
    defer app.deinit();
    rl.initAudioDevice();
    defer rl.closeAudioDevice();

    var reg = entt.Registry.init(paa.allocator());
    defer reg.deinit();

    var state = State{
        .app = &app,
        .config = &app.config,
        .sounds = .{
            .soundtrack = rl.loadSound("assets/soundtrack.wav"),
            .explosion = rl.loadSound("assets/explosion.wav"),
            .explosion_short = rl.loadSound("assets/explosion-short.wav"),
            .impact = rl.loadSound("assets/impact.wav"),
            .gameover = rl.loadSound("assets/gameover.wav"),
            .loose = rl.loadSound("assets/loose.wav"),
            .win = rl.loadSound("assets/win.wav"),
        },
        .sound_enabled = true,
        .registry = &reg,
        .invasion_zone = 0.15,
        .player_entity = undefined,
        .invader_grid = State.InvaderGridState.init(2, 4, 60),
    };
    rl.setSoundVolume(state.sounds.explosion_short, 0.4);
    rl.setSoundVolume(state.sounds.explosion, 0.4);
    rl.setSoundVolume(state.sounds.win, 0.8);
    rl.setSoundVolume(state.sounds.loose, 0.8);
    rl.setSoundVolume(state.sounds.gameover, 0.8);

    app.start();
    defer app.stop();

    while (app.isRunning()) {
        // Loop background music.
        if (!rl.isSoundPlaying(state.sounds.soundtrack)) {
            state.playSound(.soundtrack);
        }

        handleAppInput(&state);

        if (state.isPlaying()) {
            handlePlayerInput(&state);
            updateInvaders(&state);
            updateProjectiles(&state);
            checkHits(&state);
            checkInvaderGrid(&state);
        }

        beginFrame();
        renderInvasionZone(&state);
        renderEntities(&reg);
        try renderHud(&state);
        renderState(&state);
        if (app.debug_mode) {
            renderDebug(&reg);
        }
        endFrame();
    }
}

//------------------------------------------------------------------------------
// Entities
//------------------------------------------------------------------------------

fn spawnPlayer(state: *State) void {
    const reg = state.registry;

    const player_height = 20;
    const player_width = player_height * 2;
    const player = reg.create();
    reg.add(player, comp.Position{
        .x = state.config.getDisplayWidth() / 2 - player_width / 2,
        .y = state.config.getDisplayHeight() - player_height,
    });
    reg.add(player, comp.Speed.uniform(300));
    reg.add(player, comp.Shape.triangle(
        .{ player_width / 2, 0 },
        .{ 0, player_height },
        .{ player_width, player_height },
    ));
    reg.add(player, comp.Visual.stub());
    state.player_entity = player;
}

fn spawnInvaders(state: *State) void {
    const reg = state.registry;
    const grid = &state.invader_grid;
    const shape = comp.Shape.rectangle(grid.invader_width, grid.invader_height);
    for (0..grid.rows) |row| {
        for (0..grid.cols) |col| {
            const invader = reg.create();
            reg.add(invader, comp.Invader{ .health = 1 + 2 * @as(u8, @intCast(row)) });
            reg.add(invader, grid.getInvaderPosition(@intCast(row), @intCast(col)));
            reg.add(invader, comp.Speed{ .x = grid.speed, .y = grid.invader_height + grid.space });
            reg.add(invader, shape);
            reg.add(invader, comp.Visual.color(rl.Color.green, false));
            reg.add(invader, comp.Cooldown.new(1));
        }
    }
}

fn resetEntites(state: *State) void {
    var reg = state.registry;
    var invaders = reg.basicView(comp.Invader);
    var projectiles = reg.basicView(comp.Projectile);

    // Remove all invaders.
    var iter = invaders.entityIterator();
    while (iter.next()) |entity| {
        reg.destroy(entity);
    }

    // Remove all projectiles.
    iter = projectiles.entityIterator();
    while (iter.next()) |entity| {
        reg.destroy(entity);
    }

    if (reg.valid(state.player_entity)) {
        reg.destroy(state.player_entity);
    }
    spawnPlayer(state);
    spawnInvaders(state);
}

fn shoot(
    state: *State,
    direction: comp.Direction,
    position: comp.Position,
    shape: comp.Shape,
    speed: f32,
) void {
    const reg = state.registry;
    const e = reg.create();
    reg.add(e, comp.Projectile{ .direction = direction });
    reg.add(e, comp.Position{
        .x = position.x - shape.getWidth() / 2,
        .y = position.y + if (direction == .up) shape.getHeight() else 0,
    });
    reg.add(e, comp.Speed.uniform(speed));
    reg.add(e, shape);
    reg.add(e, comp.Visual.stub());
}

//------------------------------------------------------------------------------
// Input
//------------------------------------------------------------------------------

fn handleAppInput(state: *State) void {
    if (rl.windowShouldClose() or rl.isKeyPressed(rl.KeyboardKey.key_q)) {
        state.app.shutdown();
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
        state.app.toggleDebugMode();
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_f2)) {
        state.toggleSound();
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_enter)) {
        if (state.isPlaying()) {
            state.pause();
        } else {
            if (state.isReady()) {
                resetEntites(state);
            }
            state.start();
        }
    }
}

fn handlePlayerInput(state: *State) void {
    var pos = state.registry.get(comp.Position, state.player_entity);
    const speed = state.registry.getConst(comp.Speed, state.player_entity);
    const delta_time = rl.getFrameTime();

    if (rl.isKeyDown(rl.KeyboardKey.key_h) or
        rl.isKeyDown(rl.KeyboardKey.key_left))
    {
        pos.x -= speed.x * delta_time;
    }

    if (rl.isKeyDown(rl.KeyboardKey.key_l) or
        rl.isKeyDown(rl.KeyboardKey.key_right))
    {
        pos.x += speed.x * delta_time;
    }

    if (rl.isKeyPressed(rl.KeyboardKey.key_space)) {
        const player_pos = state.registry.getConst(comp.Position, state.player_entity);
        const player_shape = state.registry.getConst(comp.Shape, state.player_entity);
        shoot(
            state,
            .up,
            .{
                .x = player_pos.x + player_shape.getWidth() / 2,
                .y = player_pos.y,
            },
            comp.Shape.rectangle(4, 12),
            300,
        );
    }
}

//------------------------------------------------------------------------------
// Update
//------------------------------------------------------------------------------

fn updateProjectiles(state: *State) void {
    const delta_time = rl.getFrameTime();
    var reg = state.registry;
    var view = reg.view(.{ comp.Projectile, comp.Position, comp.Speed }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const projectile = view.getConst(comp.Projectile, entity);
        const speed = view.getConst(comp.Speed, entity);
        var pos = view.get(comp.Position, entity);

        switch (projectile.direction) {
            .up => pos.y -= speed.y * delta_time,
            .down => pos.y += speed.y * delta_time,
            else => unreachable,
        }

        const shape = reg.getConst(comp.Shape, entity);
        // Destroy the projectile, when it leaves the screen.
        if (pos.y > state.config.getDisplayHeight()) {
            // Play impact sound when projectile hits the ground.
            state.playSound(.impact);
            reg.destroy(entity);
        } else if (pos.y + shape.getHeight() < 0) {
            reg.destroy(entity);
        }
    }
}

fn updateInvaders(state: *State) void {
    var grid = &state.invader_grid;

    var offset_y: f32 = 0;
    switch (grid.direction) {
        .right, .left => {
            if (grid.offset + grid.position.x + grid.getWidth() > state.config.getDisplayWidth()) {
                offset_y = grid.space + grid.invader_height;
                grid.direction = .left;
            } else if (grid.position.x - grid.offset < 0) {
                offset_y = grid.space + grid.invader_height;
                grid.direction = .right;
            }
        },
        else => unreachable,
    }

    const factor: f32 = switch (grid.direction) {
        .left => -1,
        .right => 1,
        else => unreachable,
    };
    const normalized_speed = grid.speed * factor * rl.getFrameTime();

    // Update grid position.
    grid.position.x += normalized_speed;
    grid.position.y += offset_y;

    // Update position of all alive invaders.
    var reg = state.registry;

    const player_pos = reg.getConst(comp.Position, state.player_entity);
    const player_shape = reg.getConst(comp.Shape, state.player_entity);

    var view = reg.view(.{ comp.Invader, comp.Position, comp.Shape, comp.Cooldown }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const shape = view.get(comp.Shape, entity);
        var pos = view.get(comp.Position, entity);
        pos.x += normalized_speed;
        pos.y += offset_y;
        // Check if invader corssed the invasion zone.
        if (pos.y + shape.getHeight() > state.getInvasionZonePosition()) {
            state.loose();
            resetEntites(state);
            break;
        }

        var cooldown = view.get(comp.Cooldown, entity);
        cooldown.cool(rl.getFrameTime());
        if (cooldown.ready() and
            pos.x >= player_pos.x and
            pos.x <= player_pos.x + player_shape.getWidth())
        {
            cooldown.reset();
            shoot(
                state,
                .down,
                .{
                    .x = pos.x + shape.getWidth() / 2,
                    .y = pos.y + shape.getHeight(),
                },
                comp.Shape.triangle(.{ 0, 0 }, .{ 4, 8 }, .{ 8, 0 }),
                300,
            );
        }
    }
}

fn checkHits(state: *State) void {
    var reg = state.registry;
    var targets_view = reg.view(.{ comp.Invader, comp.Position, comp.Shape }, .{});
    var view = reg.view(.{ comp.Projectile, comp.Position, comp.Shape }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const projectile = view.getConst(comp.Projectile, entity);
        const projectile_pos = view.getConst(comp.Position, entity);
        const projectile_shape = view.getConst(comp.Shape, entity);
        var projectiles_iter = view.entityIterator();
        while (projectiles_iter.next()) |target| {
            if (entity == target) {
                continue;
            }
            const target_pos = targets_view.getConst(comp.Position, target);
            const target_shape = targets_view.getConst(comp.Shape, target);
            // Check if projectile hits another projectile.
            if (isHit(projectile_pos, projectile_shape, target_pos, target_shape)) {
                // Play impact sound when projectile hits projectile.
                state.playSound(.impact);
                // Destroy both entities.
                reg.destroy(entity);
                reg.destroy(target);
            }
        }

        const player_pos = targets_view.getConst(comp.Position, state.player_entity);
        const player_shape = targets_view.getConst(comp.Shape, state.player_entity);

        switch (projectile.direction) {
            .up => {
                var targets_iter = targets_view.entityIterator();
                while (targets_iter.next()) |target| {
                    const target_pos = targets_view.getConst(comp.Position, target);
                    const target_shape = targets_view.getConst(comp.Shape, target);
                    // Check if projectile hits invader.
                    if (isHit(projectile_pos, projectile_shape, target_pos, target_shape)) {
                        state.playSound(.explosion_short);
                        // Destroy both entities.
                        reg.destroy(entity);
                        reg.destroy(target);
                        // Reduce number of alive invaders in grid.
                        state.invader_grid.alive -= 1;
                    }
                }
            },
            .down => {
                // Check if projectile hits player.
                if (isHit(projectile_pos, projectile_shape, player_pos, player_shape)) {
                    state.playSound(.explosion);
                    // Destroy projectile entity.
                    state.loose();
                    resetEntites(state);
                }
            },
            else => unreachable,
        }
    }
}

fn isHit(
    projectile_pos: comp.Position,
    projectile_shape: comp.Shape,
    target_pos: comp.Position,
    target_shape: comp.Shape,
) bool {
    const projectile_rect = rl.Rectangle{
        .x = projectile_pos.x,
        .y = projectile_pos.y,
        .width = projectile_shape.getWidth(),
        .height = projectile_shape.getHeight(),
    };
    const target_rect = rl.Rectangle{
        .x = target_pos.x,
        .y = target_pos.y,
        .width = target_shape.getWidth(),
        .height = target_shape.getHeight(),
    };
    return rl.checkCollisionRecs(projectile_rect, target_rect);
}

/// Make the player win, once all invaders in the grid are dead.
fn checkInvaderGrid(state: *State) void {
    if (state.invader_grid.alive == 0) {
        state.win();
        resetEntites(state);
    }
}

//------------------------------------------------------------------------------
// Rendering
//------------------------------------------------------------------------------

fn beginFrame() void {
    rl.beginDrawing();
    rl.clearBackground(rl.Color.black);
}

fn endFrame() void {
    rl.endDrawing();
}

/// Render debug information and entity shape AABB's.
fn renderDebug(reg: *entt.Registry) void {
    rl.drawFPS(10, 10);
    var view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var pos = view.getConst(comp.Position, entity);
        const shape = view.getConst(comp.Shape, entity);
        if (shape == .circle) {
            pos.x -= shape.getWidth() / 2;
            pos.y -= shape.getHeight() / 2;
        }
        renderEntity(
            pos,
            comp.Shape.rectangle(shape.getWidth(), shape.getHeight()),
            comp.Visual.color(rl.Color.yellow, true),
        );
    }
}

fn renderEntities(reg: *entt.Registry) void {
    var view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const pos = view.getConst(comp.Position, entity);
        const shape = view.getConst(comp.Shape, entity);
        const visual = view.getConst(comp.Visual, entity);
        renderEntity(pos, shape, visual);
    }
}

fn renderEntity(pos: comp.Position, shape: comp.Shape, visual: comp.Visual) void {
    switch (visual) {
        .stub => renderStub(pos, shape),
        .color => renderShape(pos, shape, visual.color.value, visual.color.outline),
    }
}

fn renderInvasionZone(state: *const State) void {
    renderShape(
        comp.Position{
            .x = 0,
            .y = state.getInvasionZonePosition(),
        },
        comp.Shape{
            .rectangle = .{
                .width = state.config.getDisplayWidth(),
                .height = state.config.getDisplayHeight() - state.getInvasionZonePosition(),
            },
        },
        rl.Color.yellow.alpha(0.1),
        false,
    );
}

fn renderHud(state: *const State) !void {
    const color = rl.Color.ray_white;
    const size = 16;
    const offset_y = size;
    const offset_x = 130;
    var text_buf: [255]u8 = undefined;
    const score_text = try std.fmt.bufPrintZ(&text_buf, "Lives: {d}", .{state.lives});
    rl.drawText(
        score_text,
        @as(i32, @intFromFloat(state.config.getDisplayWidth())) - offset_x,
        offset_y,
        size,
        color,
    );
    const lives_text = try std.fmt.bufPrintZ(&text_buf, "Score: {d}", .{state.score});
    rl.drawText(
        lives_text,
        @as(i32, @intFromFloat(state.config.getDisplayWidth())) - offset_x,
        offset_y * 1 + size,
        size,
        color,
    );
    const wave_text = try std.fmt.bufPrintZ(&text_buf, "Wave: {d}", .{state.invader_grid.wave + 1});
    rl.drawText(
        wave_text,
        @as(i32, @intFromFloat(state.config.getDisplayWidth())) - offset_x,
        offset_y * 2 + size,
        size,
        color,
    );
}

fn renderState(state: *const State) void {
    const color = rl.Color.ray_white;
    const size = 24;
    switch (state.status) {
        .ready => renderTextCentered(state.config, "Press [Enter] to start", size, color),
        .playing => {},
        .paused => renderTextCentered(state.config, "Press [Enter] to resume", size, color),
        .won => renderTextCentered(state.config, "Invaders defeated!\nGet ready for the next wave!\nPress [Enter] to start", size, color),
        .lost => renderTextCentered(state.config, "You lost!\nPress [Enter] to retry", size, color),
        .gameover => renderTextCentered(state.config, "GAME OVER", size, color),
    }
}

fn renderTextCentered(
    config: *const ApplicationConfig,
    text: [*:0]const u8,
    size: i32,
    color: rl.Color,
) void {
    const text_width: f32 = @floatFromInt(rl.measureText(text, size));
    rl.drawText(
        text,
        @as(i32, @intFromFloat(config.getDisplayWidth() / 2 - text_width / 2)),
        @as(i32, @intFromFloat(config.getDisplayHeight() / 2)) - @divTrunc(size, 2),
        size,
        color,
    );
}

/// Render a stub shape.
/// TODO: Make visual appearance more noticeable.
fn renderStub(pos: comp.Position, shape: comp.Shape) void {
    renderShape(pos, shape, rl.Color.magenta, false);
}

/// Generic rendering function to be used for `stub` and `color` visuals.
fn renderShape(pos: comp.Position, shape: comp.Shape, color: rl.Color, outline: bool) void {
    const p = .{ .x = pos.x, .y = pos.y };
    switch (shape) {
        .triangle => {
            const v1 = .{
                .x = p.x + shape.triangle.v1[0],
                .y = p.y + shape.triangle.v1[1],
            };
            const v2 = .{
                .x = p.x + shape.triangle.v2[0],
                .y = p.y + shape.triangle.v2[1],
            };
            const v3 = .{
                .x = p.x + shape.triangle.v3[0],
                .y = p.y + shape.triangle.v3[1],
            };
            if (outline) {
                rl.drawTriangleLines(v1, v2, v3, color);
            } else {
                rl.drawTriangle(v1, v2, v3, color);
            }
        },
        .rectangle => {
            const size = .{ .x = shape.rectangle.width, .y = shape.rectangle.height };
            if (outline) {
                // NOTE: The `drawRectangleLines` function draws the outlined
                // rectangle incorrectly. Hence, drawing the lines individually.
                const v1 = .{ .x = p.x, .y = p.y };
                const v2 = .{ .x = p.x + size.x, .y = p.y };
                const v3 = .{ .x = p.x + size.x, .y = p.y + size.y };
                const v4 = .{ .x = p.x, .y = p.y + size.y };
                rl.drawLineV(v1, v2, color);
                rl.drawLineV(v2, v3, color);
                rl.drawLineV(v3, v4, color);
                rl.drawLineV(v4, v1, color);
            } else {
                rl.drawRectangleV(p, size, color);
            }
        },
        .circle => {
            if (outline) {
                rl.drawCircleLinesV(p, shape.circle.radius, color);
            } else {
                rl.drawCircleV(p, shape.circle.radius, color);
            }
        },
    }
}
