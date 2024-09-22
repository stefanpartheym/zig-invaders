const std = @import("std");
const entt = @import("entt");
const rl = @import("raylib");

const PlatformAgnosticAllocator = @import("paa.zig");
const Application = @import("application.zig").Application;
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
        .config = &app.config,
        .registry = &reg,
        .entities = .{
            .player = undefined,
            .alien_grid = undefined,
        },
    };

    setupEntites(&state);

    app.start();
    defer app.stop();

    while (app.isRunning()) {
        handleAppInput(&app);
        handlePlayerInput(&state);

        updateAliens(&state);
        updateProjectiles(&state);
        checkPlayerHits(&state);

        beginFrame();
        render(&reg);
        if (app.debug_mode) {
            debugRender();
        }
        endFrame();
    }
}

//------------------------------------------------------------------------------
// Entities
//------------------------------------------------------------------------------

fn setupEntites(state: *State) void {
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

    spawnAliens(state, 2, 5, 60);
}

fn spawnAliens(state: *State, rows: u8, cols: u8, speed: f32) void {
    const reg = state.registry;
    const grid = State.AlienGridState.init(rows, cols, speed);
    const shape = comp.Shape.rectangle(grid.alien_width, grid.alien_height);
    for (0..rows) |row| {
        for (0..cols) |col| {
            const alien = reg.create();
            reg.add(alien, comp.Alien{ .health = 1 + 2 * @as(u8, @intCast(row)) });
            reg.add(alien, grid.getAlienPosition(@intCast(row), @intCast(col)));
            reg.add(alien, comp.Speed{ .x = grid.speed, .y = grid.alien_height + grid.space });
            reg.add(alien, shape);
            reg.add(alien, comp.Visual.color(rl.Color.green));
        }
    }

    state.entities.alien_grid = grid;
}

fn shoot(state: *State) void {
    const reg = state.registry;
    const player_pos = reg.getConst(comp.Position, state.entities.player);
    const player_shape = reg.getConst(comp.Shape, state.entities.player);
    const shape = comp.Shape.rectangle(4, 12);
    const e = reg.create();
    reg.add(e, comp.Projectile.up());
    reg.add(e, comp.Position{
        .x = player_pos.x + player_shape.rectangle.width / 2 - shape.rectangle.width / 2,
        .y = player_pos.y - shape.rectangle.height,
    });
    reg.add(e, comp.Speed.uniform(500));
    reg.add(e, shape);
    reg.add(e, comp.Visual.stub());
}

//------------------------------------------------------------------------------
// Input
//------------------------------------------------------------------------------

fn handleAppInput(app: *Application) void {
    if (rl.windowShouldClose() or rl.isKeyPressed(rl.KeyboardKey.key_q)) {
        app.shutdown();
    }
    if (rl.isKeyPressed(rl.KeyboardKey.key_f1)) {
        app.toggleDebugMode();
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
        shoot(state);
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
        // Destroy the entity, if it leaves the screen.
        // TODO: Also check projectiles going downwards.
        if (pos.y + shape.getHeight() < 0) {
            reg.destroy(entity);
        }
    }
}

fn updateAliens(state: *State) void {
    var grid = &state.entities.alien_grid;

    var offset_y: f32 = 0;

    switch (grid.direction) {
        .right => if (grid.offset + grid.position.x + grid.getWidth() > state.config.getDisplayWidth()) {
            grid.direction = .left;
            offset_y = grid.space + grid.alien_height;
        },
        .left => if (grid.position.x - grid.offset < 0) {
            grid.direction = .right;
            offset_y = grid.space + grid.alien_height;
        },
        else => unreachable,
    }

    const factor: f32 = switch (grid.direction) {
        .left => -1,
        .right => 1,
        else => unreachable,
    };
    const normalized_speed = grid.speed * factor * rl.getFrameTime();

    var reg = state.registry;
    var view = reg.view(.{ comp.Alien, comp.Position }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        var pos = view.get(comp.Position, entity);
        pos.x += normalized_speed;
        pos.y += offset_y;
    }

    grid.position.x += normalized_speed;
    grid.position.y += offset_y;
}

fn checkPlayerHits(state: *State) void {
    var reg = state.registry;
    var targets_view = reg.view(.{ comp.Alien, comp.Position, comp.Shape }, .{});
    var view = reg.view(.{ comp.Projectile, comp.Position, comp.Shape }, .{});
    var iter = view.entityIterator();
    while (iter.next()) |entity| {
        const projectile = view.getConst(comp.Projectile, entity);
        if (projectile.direction == .up) {
            const pos = view.getConst(comp.Position, entity);
            const shape = view.getConst(comp.Shape, entity);

            var targets_iter = targets_view.entityIterator();
            while (targets_iter.next()) |target| {
                const target_pos = targets_view.getConst(comp.Position, target);
                const target_shape = targets_view.getConst(comp.Shape, target);

                const projectile_rect = rl.Rectangle{
                    .x = pos.x,
                    .y = pos.y,
                    .width = shape.rectangle.width,
                    .height = shape.rectangle.height,
                };
                const target_rect = rl.Rectangle{
                    .x = target_pos.x,
                    .y = target_pos.y,
                    .width = target_shape.rectangle.width,
                    .height = target_shape.rectangle.height,
                };

                // Check if projectile hits alien.
                if (rl.checkCollisionRecs(projectile_rect, target_rect)) {
                    // Destroy both entities.
                    reg.destroy(entity);
                    reg.destroy(target);
                    // Reduce number of alive aliens in grid.
                    state.entities.alien_grid.alive -= 1;
                }
            }
        }
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

fn render(reg: *entt.Registry) void {
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
