const entt = @import("entt");
const comp = @import("components.zig");
const ApplicationConfig = @import("application.zig").ApplicationConfig;

config: *const ApplicationConfig,
registry: *entt.Registry,
entities: struct {
    player: entt.Entity,
    alien_grid: AlienGridState,
},

pub const AlienGridState = struct {
    const Self = @This();

    /// Number of rows in the grid.
    rows: u8,
    /// Number of aliens per row.
    cols: u8,
    /// Speed of the grid.
    speed: f32,
    /// Current position of the grid on the screen (reference point is top-left corner).
    position: comp.Position,
    /// Current direction in which the grid moves (either `left` or `right`).
    direction: comp.Direction,
    /// Width of an alien within the grid.
    alien_width: f32,
    /// Height of an alien within the grid.
    alien_height: f32,
    /// Space between the aliens.
    space: f32,
    /// The grid's offset to the edges of the screen.
    offset: f32,
    /// Number of currently alive aliens in the grid.
    alive: u8,

    pub fn init(rows: u8, cols: u8, speed: f32) Self {
        const offset = 50;

        return Self{
            .rows = rows,
            .cols = cols,
            .speed = speed,
            .position = .{
                .x = offset,
                .y = offset,
            },
            .direction = .right,
            .alien_width = 30,
            .alien_height = 25,
            .space = 40,
            .offset = offset,
            .alive = rows * cols,
        };
    }

    pub fn getWidth(self: *const Self) f32 {
        const factor = @as(f32, @floatFromInt(self.cols));
        return (self.alien_width + self.space) * factor - self.space;
    }

    pub fn getHeight(self: *const Self) f32 {
        const factor = @as(f32, @floatFromInt(self.rows));
        return (self.alien_height + self.space) * factor - self.space;
    }

    pub fn getAlienPosition(self: *const Self, row: u8, col: u8) comp.Position {
        return comp.Position{
            .x = self.offset + (self.alien_width + self.space) * @as(f32, @floatFromInt(col)),
            .y = self.offset + (self.alien_height + self.space) * @as(f32, @floatFromInt(row)),
        };
    }
};
