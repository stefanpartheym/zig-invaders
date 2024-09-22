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

    /// Number of minimum rows in the grid.
    min_rows: u8,
    /// Number of minimum aliens per row.
    min_cols: u8,
    /// Width of an alien within the grid.
    alien_width: f32,
    /// Height of an alien within the grid.
    alien_height: f32,
    /// Space between the aliens.
    space: f32,
    /// The grid's offset to the edges of the screen.
    offset: f32,
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
    /// Number of currently alive aliens in the grid.
    alive: u8,

    pub fn init(min_rows: u8, min_cols: u8, speed: f32) Self {
        const offset = 50;
        return Self{
            .min_rows = min_rows,
            .min_cols = min_cols,
            .rows = min_rows,
            .cols = min_cols,
            .speed = speed,
            .alien_width = 30,
            .alien_height = 25,
            .space = 40,
            .offset = offset,
            .position = .{
                .x = offset,
                .y = offset,
            },
            .direction = .right,
            .alive = 0,
        };
    }

    pub fn spawn(self: *Self, rows: u8, cols: u8, speed: f32) void {
        self.rows = rows;
        self.cols = cols;
        self.speed = speed;
        self.position = .{ .x = self.offset, .y = self.offset };
        self.direction = .right;
        self.alive = rows * cols;
    }

    /// Returns current grid width in pixel.
    pub fn getWidth(self: *const Self) f32 {
        const factor = @as(f32, @floatFromInt(self.cols));
        return (self.alien_width + self.space) * factor - self.space;
    }

    /// Returns current grid height in pixel.
    pub fn getHeight(self: *const Self) f32 {
        const factor = @as(f32, @floatFromInt(self.rows));
        return (self.alien_height + self.space) * factor - self.space;
    }

    /// Returns the position on the screen of the alien at `row`:`col`.
    pub fn getAlienPosition(self: *const Self, row: u8, col: u8) comp.Position {
        return comp.Position{
            .x = self.offset + (self.alien_width + self.space) * @as(f32, @floatFromInt(col)),
            .y = self.offset + (self.alien_height + self.space) * @as(f32, @floatFromInt(row)),
        };
    }
};
