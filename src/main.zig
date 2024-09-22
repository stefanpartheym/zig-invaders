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

    var reg = entt.Registry.init(paa.allocator());
    defer reg.deinit();

    var state = State{
        .app = &app,
        .config = &app.config,
        .registry = &reg,
        .invasion_zone = 0.15,
        .entities = .{
            .player = undefined,
            .alien_grid = State.AlienGridState.init(2, 4, 60),
        },
    };

    app.start();
    defer app.stop();

    while (app.isRunning()) {
        handleAppInput(&state);

        if (state.isPlaying()) {
            handlePlayerInput(&state);
            updateAliens(&state);
            updateProjectiles(&state);
            checkHits(&state);
            checkAlienGrid(&state);
        }

        beginFrame();
        renderInvasionZone(&state);
        renderEntities(&reg);
        try renderHud(&state);
        renderState(&state);
        if (app.debug_mode) {
            debugRender();
        }
        endFrame();
    }
}

//------------------------------------------------------------------------------
// Entities
//------------------------------------------------------------------------------

fn spawnPlayer(state: *State) void {
    const reg = state.registry;

    const player_size = 50;
    const player = reg.create();
    reg.add(player, comp.Position{
        .x = state.config.getDisplayWidth() / 2 - player_size / 2,
        .y = state.config.getDisplayHeight() - player_size,
    });
    reg.add(player, comp.Speed.uniform(300));
    reg.add(player, comp.Shape{
        .rectangle = .{
            .width = player_size,
            .height = player_size,
        },
    });
    reg.add(player, comp.Visual.stub());
    state.entities.player = player;
}

fn spawnAliens(state: *State) void {
    const reg = state.registry;
    const grid = &state.entities.alien_grid;
    const shape = comp.Shape.rectangle(grid.alien_width, grid.alien_height);
    for (0..grid.rows) |row| {
        for (0..grid.cols) |col| {
            const alien = reg.create();
            reg.add(alien, comp.Alien{ .health = 1 + 2 * @as(u8, @intCast(row)) });
            reg.add(alien, grid.getAlienPosition(@intCast(row), @intCast(col)));
            reg.add(alien, comp.Speed{ .x = grid.speed, .y = grid.alien_height + grid.space });
            reg.add(alien, shape);
            reg.add(alien, comp.Visual.color(rl.Color.green));
            reg.add(alien, comp.Cooldown.new(1));
        }
    }
}

fn resetEntites(state: *State) void {
    var reg = state.registry;
    var aliens = reg.basicView(comp.Alien);
    var projectiles = reg.basicView(comp.Projectile);

    // Remove all aliens.
    var iter = aliens.entityIterator();
    while (iter.next()) |entity| {
        reg.destroy(entity);
    }

    // Remove all projects.
    iter = projectiles.entityIterator();
    while (iter.next()) |entity| {
        reg.destroy(entity);
    }

    if (reg.valid(state.entities.player)) {
        reg.destroy(state.entities.player);
    }
    spawnPlayer(state);
    spawnAliens(state);
}

fn shoot(state: *State, direction: comp.Direction, position: comp.Position, speed: f32) void {
    const reg = state.registry;
    const shape = comp.Shape.rectangle(4, 12);
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
    var pos = state.registry.get(comp.Position, state.entities.player);
    const speed = state.registry.getConst(comp.Speed, state.entities.player);
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
        const player_pos = state.registry.getConst(comp.Position, state.entities.player);
        const player_shape = state.registry.getConst(comp.Shape, state.entities.player);
        shoot(
            state,
            .up,
            .{
                .x = player_pos.x + player_shape.getWidth() / 2,
                .y = player_pos.y,
            },
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
        // Destroy the entity, when it leaves the screen.
        if (pos.y > state.config.getDisplayHeight() or
            pos.y + shape.getHeight() < 0)
        {
            reg.destroy(entity);
        }
    }
}

fn updateAliens(state: *State) void {
    var grid = &state.entities.alien_grid;

    var offset_y: f32 = 0;
    switch (grid.direction) {
        .right, .left => {
            if (grid.offset + grid.position.x + grid.getWidth() > state.config.getDisplayWidth()) {
                offset_y = grid.space + grid.alien_height;
                grid.direction = .left;
            } else if (grid.position.x - grid.offset < 0) {
                offset_y = grid.space + grid.alien_height;
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

    // Update position of all alive aliens.
    var reg = state.registry;

    const player_pos = reg.getConst(comp.Position, state.entities.player);
    const player_shape = reg.getConst(comp.Shape, state.entities.player);

    var view = reg.view(.{ comp.Alien, comp.Position, comp.Shape, comp.Cooldown }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const shape = view.get(comp.Shape, entity);
        var pos = view.get(comp.Position, entity);
        pos.x += normalized_speed;
        pos.y += offset_y;
        // Check if alien corssed the invasion zone.
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
                300,
            );
        }
    }
}

fn checkHits(state: *State) void {
    var reg = state.registry;
    var targets_view = reg.view(.{ comp.Alien, comp.Position, comp.Shape }, .{});
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
                // Destroy both entities.
                reg.destroy(entity);
                reg.destroy(target);
            }
        }

        const player_pos = targets_view.getConst(comp.Position, state.entities.player);
        const player_shape = targets_view.getConst(comp.Shape, state.entities.player);

        switch (projectile.direction) {
            .up => {
                var targets_iter = targets_view.entityIterator();
                while (targets_iter.next()) |target| {
                    const target_pos = targets_view.getConst(comp.Position, target);
                    const target_shape = targets_view.getConst(comp.Shape, target);
                    // Check if projectile hits alien.
                    if (isHit(projectile_pos, projectile_shape, target_pos, target_shape)) {
                        // Destroy both entities.
                        reg.destroy(entity);
                        reg.destroy(target);
                        // Reduce number of alive aliens in grid.
                        state.entities.alien_grid.alive -= 1;
                    }
                }
            },
            .down => {
                // Check if projectile hits player.
                if (isHit(projectile_pos, projectile_shape, player_pos, player_shape)) {
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
        .width = projectile_shape.rectangle.width,
        .height = projectile_shape.rectangle.height,
    };
    const target_rect = rl.Rectangle{
        .x = target_pos.x,
        .y = target_pos.y,
        .width = target_shape.getWidth(),
        .height = target_shape.getHeight(),
    };
    return rl.checkCollisionRecs(projectile_rect, target_rect);
}

/// Checks all aliens in the grid are dead and spawn the next wave of aliens.
fn checkAlienGrid(state: *State) void {
    if (state.entities.alien_grid.alive == 0) {
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

fn debugRender() void {
    rl.drawFPS(10, 10);
}

fn renderEntities(reg: *entt.Registry) void {
    var view = reg.view(.{ comp.Position, comp.Shape, comp.Visual }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const pos = view.getConst(comp.Position, entity);
        const shape = view.getConst(comp.Shape, entity);
        const visual = view.getConst(comp.Visual, entity);
        switch (visual) {
            .stub => renderStub(pos, shape),
            .color => renderShape(pos, shape, visual.color.value),
        }
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
    const wave_text = try std.fmt.bufPrintZ(&text_buf, "Wave: {d}", .{state.entities.alien_grid.wave + 1});
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
        .ready => renderTextCentered(state.config, "Press [Enter] to start.", size, color),
        .playing => {},
        .paused => renderTextCentered(state.config, "Paused\nPress [Enter] to resume.", size, color),
        .won => renderTextCentered(state.config, "You defeated the enemy!\nPress [Enter] when your're ready for the next wave.", size, color),
        .lost => renderTextCentered(state.config, "You lost!\nPress [Enter] to retry.", size, color),
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
    renderShape(pos, shape, rl.Color.magenta);
}

/// Generic rendering function to be used for `stub` and `color` visuals.
fn renderShape(pos: comp.Position, shape: comp.Shape, color: rl.Color) void {
    switch (shape) {
        .rectangle => rl.drawRectangleV(
            .{ .x = pos.x, .y = pos.y },
            .{ .x = shape.rectangle.width, .y = shape.rectangle.height },
            color,
        ),
        .circle => rl.drawCircleV(
            .{ .x = pos.x, .y = pos.y },
            shape.circle.radius,
            color,
        ),
    }
}
