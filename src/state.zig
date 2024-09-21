const entt = @import("entt");
const comp = @import("components.zig");
const ApplicationConfig = @import("application.zig").ApplicationConfig;

config: *const ApplicationConfig,
registry: *entt.Registry,
entities: struct {
    player: entt.Entity,
    alien_grid: struct {
        position: comp.Position,
        direction: comp.Direction,
        rows: u8,
        cols: u8,
        alien_width: f32,
        alien_height: f32,
        space: f32,
        offset: f32,
        speed: f32,
    },
},
