const rl = @import("raylib");

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const Speed = struct {
    const Self = @This();

    x: f32,
    y: f32,

    pub fn uniform(value: f32) Self {
        return Self{ .x = value, .y = value };
    }
};

pub const ShapeType = enum {
    triangle,
    rectangle,
    circle,
};

pub const Shape = union(ShapeType) {
    const Self = @This();
    const Vec2 = @Vector(2, f32);

    triangle: struct {
        v1: Vec2,
        v2: Vec2,
        v3: Vec2,
    },
    rectangle: struct {
        width: f32,
        height: f32,
    },
    circle: struct {
        radius: f32,
    },

    pub fn triangle(v1: Vec2, v2: Vec2, v3: Vec2) Self {
        return Self{
            .triangle = .{
                .v1 = v1,
                .v2 = v2,
                .v3 = v3,
            },
        };
    }

    pub fn rectangle(width: f32, height: f32) Self {
        return Self{
            .rectangle = .{
                .width = width,
                .height = height,
            },
        };
    }

    pub fn circle(radius: f32) Self {
        return Self{
            .circle = .{ .radius = radius },
        };
    }

    pub fn getWidth(self: *const Self) f32 {
        switch (self.*) {
            .triangle => return self.getTriangleVectorLength(0),
            .rectangle => return self.rectangle.width,
            .circle => return self.circle.radius * 2,
        }
    }

    pub fn getHeight(self: *const Self) f32 {
        switch (self.*) {
            .triangle => return self.getTriangleVectorLength(1),
            .rectangle => return self.rectangle.height,
            .circle => return self.circle.radius * 2,
        }
    }

    fn getTriangleVectorLength(self: *const Self, dimension: u8) f32 {
        const v1 = self.triangle.v1;
        const v2 = self.triangle.v2;
        const v3 = self.triangle.v3;
        return @max(@max(v1[dimension], v2[dimension]), v3[dimension]) -
            @min(@min(v1[dimension], v2[dimension]), v3[dimension]);
    }
};

pub const VisualType = enum {
    stub,
    color,
};

pub const Visual = union(VisualType) {
    const Self = @This();

    stub: struct {
        /// In order for the ECS to correctly handle the component, it needs at
        /// least one property.
        value: u8,
    },
    color: struct {
        value: rl.Color,
        outline: bool,
    },

    /// Creates a stub Visual component.
    pub fn stub() Self {
        return Self{
            .stub = .{ .value = 1 },
        };
    }

    /// Creates a stub Visual component.
    pub fn color(value: rl.Color, outline: bool) Self {
        return Self{
            .color = .{
                .value = value,
                .outline = outline,
            },
        };
    }
};

// ---

pub const Direction = enum {
    up,
    down,
    left,
    right,
};

pub const Projectile = struct {
    const Self = @This();

    direction: Direction,
    damage: u8 = 1,

    pub fn up() Self {
        return Self{ .direction = .up };
    }

    pub fn down() Self {
        return Self{ .direction = .down };
    }
};

pub const Invader = struct {
    /// Health or lives of the invader.
    health: u8,
};

pub const Cooldown = struct {
    const Self = @This();

    /// Cooldown value in seconds.
    value: f32,
    /// Current cooldown state.
    state: f32 = 0,

    pub fn new(value: f32) Self {
        return Self{ .value = value };
    }

    pub fn reset(self: *Self) void {
        self.state = self.value;
    }

    pub fn cool(self: *Self, value: f32) void {
        self.state -= @min(value, self.state);
    }

    pub fn ready(self: *const Self) bool {
        return self.state == 0;
    }
};
