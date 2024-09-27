const entt = @import("entt");
const rl = @import("raylib");
const comp = @import("components.zig");
const app = @import("application.zig");
const TextureStore = @import("store.zig").TextureStore;

const State = @This();
const max_lives = 3;
const Sounds = enum {
    soundtrack,
    explosion,
    explosion_short,
    impact,
    gameover,
    loose,
    win,
};

app: *app.Application,
config: *const app.ApplicationConfig,
texture_store: *TextureStore,
sounds: struct {
    soundtrack: rl.Sound,
    explosion: rl.Sound,
    explosion_short: rl.Sound,
    impact: rl.Sound,
    gameover: rl.Sound,
    loose: rl.Sound,
    win: rl.Sound,
},
sound_enabled: bool,
registry: *entt.Registry,
player_entity: entt.Entity,
invader_grid: InvaderGridState,
/// Value in percent, that indicates how far up from the bottom of the screen
/// invasion zone begins.
/// If an invader crosses the invasion zone, the player loses.
invasion_zone: f32,

status: Status = .ready,
score: u8 = 0,
lives: u8 = max_lives,

pub fn playSound(self: *State, sound_type: Sounds) void {
    if (self.sound_enabled) {
        const sound: rl.Sound =
            switch (sound_type) {
            .soundtrack => self.sounds.soundtrack,
            .explosion => self.sounds.explosion,
            .explosion_short => self.sounds.explosion_short,
            .impact => self.sounds.impact,
            .gameover => self.sounds.gameover,
            .loose => self.sounds.loose,
            .win => self.sounds.win,
        };
        rl.playSound(sound);
    }
}

pub fn toggleSound(self: *State) void {
    self.sound_enabled = !self.sound_enabled;
    if (!self.sound_enabled) {
        rl.stopSound(self.sounds.soundtrack);
        rl.stopSound(self.sounds.explosion);
        rl.stopSound(self.sounds.explosion_short);
        rl.stopSound(self.sounds.impact);
        rl.stopSound(self.sounds.gameover);
        rl.stopSound(self.sounds.loose);
        rl.stopSound(self.sounds.win);
    }
}

pub fn start(self: *State) void {
    self.status = .playing;
}

pub fn pause(self: *State) void {
    self.status = .paused;
}

pub fn win(self: *State) void {
    self.playSound(.win);
    self.score += 1;
    self.status = .won;
    self.invader_grid.nextWave();
}

pub fn loose(self: *State) void {
    self.lives -= 1;
    if (self.lives > 0) {
        self.playSound(.loose);
        self.status = .lost;
        self.invader_grid.resetWave();
    } else {
        self.playSound(.gameover);
        self.status = .gameover;
        self.lives = max_lives;
        self.score = 0;
        self.invader_grid.reset();
    }
}

pub fn isReady(self: *State) bool {
    return self.status == .ready;
}

pub fn isPlaying(self: *State) bool {
    return self.status == .playing;
}

/// Returns the Y position on the screen of the invasion zone.
pub fn getInvasionZonePosition(self: *const State) f32 {
    const display_height = self.config.getDisplayHeight();
    return display_height - display_height * self.invasion_zone;
}

pub const Status = enum {
    ready,
    paused,
    playing,
    won,
    lost,
    gameover,
};

pub const InvaderGridState = struct {
    const Self = @This();

    /// Number of minimum rows in the grid.
    min_rows: u8,
    /// Number of minimum invaders per row.
    min_cols: u8,
    /// Minimum speed.
    min_speed: f32,
    /// Number of rows for current wave.
    wave_rows: u8,
    /// Number of invaders for current wave.
    wave_cols: u8,
    /// Width of an invader within the grid.
    invader_width: f32,
    /// Height of an invader within the grid.
    invader_height: f32,
    /// Space between the invaders.
    space: f32,
    /// The grid's offset to the edges of the screen.
    offset: f32,
    /// Current wave.
    wave: u8,
    /// Number of rows in the grid.
    rows: u8,
    /// Number of invaders per row.
    cols: u8,
    /// Speed of the grid.
    speed: f32,
    /// Current position of the grid on the screen (reference point is top-left corner).
    position: comp.Position,
    /// Current direction in which the grid moves (either `left` or `right`).
    direction: comp.Direction,
    /// Number of currently alive invaders in the grid.
    alive: u8,

    pub fn init(min_rows: u8, min_cols: u8, min_speed: f32) Self {
        const offset = 50;
        return Self{
            .min_rows = min_rows,
            .min_cols = min_cols,
            .min_speed = min_speed,
            .wave_rows = min_rows,
            .wave_cols = min_cols,
            .invader_width = 30,
            .invader_height = 25,
            .space = 40,
            .offset = offset,
            .wave = 0,
            .rows = min_rows,
            .cols = min_cols,
            .speed = min_speed,
            .position = .{
                .x = offset,
                .y = offset,
            },
            .direction = .right,
            .alive = min_rows * min_cols,
        };
    }

    pub fn resetWave(self: *Self) void {
        self.rows = self.wave_rows;
        self.cols = self.wave_cols;
        self.position = .{ .x = self.offset, .y = self.offset };
        self.direction = .right;
        self.alive = self.wave_rows * self.wave_cols;
    }

    pub fn reset(self: *Self) void {
        self.rows = self.min_rows;
        self.cols = self.min_cols;
        self.speed = self.min_speed;
        self.position = .{ .x = self.offset, .y = self.offset };
        self.direction = .right;
        self.alive = self.min_rows * self.min_cols;
        self.wave = 0;
    }

    pub fn nextWave(self: *Self) void {
        var rows = self.rows;
        var cols = self.cols;
        if (self.cols == 7) {
            cols = self.min_cols;
            rows += 1;
        } else {
            cols += 1;
        }
        self.wave += 1;
        self.wave_rows = rows;
        self.wave_cols = cols;
        self.speed = self.speed * 1.05;
        self.resetWave();
    }

    /// Returns current grid width in pixel.
    pub fn getWidth(self: *const Self) f32 {
        const factor = @as(f32, @floatFromInt(self.cols));
        return (self.invader_width + self.space) * factor - self.space;
    }

    /// Returns current grid height in pixel.
    pub fn getHeight(self: *const Self) f32 {
        const factor = @as(f32, @floatFromInt(self.rows));
        return (self.invader_height + self.space) * factor - self.space;
    }

    /// Returns the position on the screen of the invader at `row`:`col`.
    pub fn getInvaderPosition(self: *const Self, row: u8, col: u8) comp.Position {
        return comp.Position{
            .x = self.offset + (self.invader_width + self.space) * @as(f32, @floatFromInt(col)),
            .y = self.offset + (self.invader_height + self.space) * @as(f32, @floatFromInt(row)),
        };
    }
};
