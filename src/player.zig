const std = @import("std");
const m = std.math;

const zm = @import("zm");

const debug = @import("debug.zig");
const engine = @import("engine/engine.zig");

pub var player_pos: zm.Vec3f = undefined;
pub var player_cam: Cam = undefined;

var player_speed: f32 = undefined;
var player_sensitivity: f32 = undefined;

// ##### Apply Uniforms #####
pub fn applyView(location: c_int) void {
    engine.gl.UniformMatrix4fv(
        location,
        1,
        engine.gl.FALSE,
        @ptrCast(&player_cam.view.data),
    );
}

pub fn applyProj(location: c_int) void {
    engine.gl.UniformMatrix4fv(
        location,
        1,
        engine.gl.FALSE,
        @ptrCast(&player_cam.proj.data),
    );
}

// ##### Callbacks #####
var prev_xpos: f64 = 0;
var prev_ypos: f64 = 0;
var first_input: bool = true;
fn cursorCallback(_: engine.Window, xpos: f64, ypos: f64) void {
    if (first_input) {
        prev_xpos = xpos;
        prev_ypos = ypos;
        first_input = false;
    }

    player_cam.rotate(
        player_pos,
        @as(f32, @floatCast(xpos - prev_xpos)) * player_sensitivity,
        -@as(f32, @floatCast(ypos - prev_ypos)) * player_sensitivity,
    );

    prev_xpos = xpos;
    prev_ypos = ypos;
}

fn frameBufferSizeCallback(width: u32, height: u32) void {
    player_cam.updateProjection(width, height);
}

// ##### General Player Functions #####
pub fn init(starting_pos: zm.Vec3f, speed: f32, sensitivity: f32, fov: f32) !void {
    player_speed = speed;
    player_sensitivity = sensitivity;

    player_pos = starting_pos;
    player_cam = Cam.init(fov, starting_pos, engine.window_width, engine.window_height);

    engine.window.setCursorPosCallback(cursorCallback);
    try engine.registerFrameBufferSizeCallback(frameBufferSizeCallback);
}

pub fn tick(delta_time: f32) void {
    const forward: zm.Vec3f = .{ player_cam.dir[0], 0, player_cam.dir[2] };
    const up: zm.Vec3f = .{ 0, 1, 0 };

    var movement: zm.Vec3f = zm.vec.zero(3, f32);

    if (engine.keyPressed(engine.Key.w)) {
        movement += forward;
    }
    if (engine.keyPressed(engine.Key.s)) {
        movement -= forward;
    }
    if (engine.keyPressed(engine.Key.d)) {
        movement += player_cam.right;
    }
    if (engine.keyPressed(engine.Key.a)) {
        movement -= player_cam.right;
    }
    if (engine.keyPressed(engine.Key.space)) {
        movement += up;
    }
    if (engine.keyPressed(engine.Key.left_control)) {
        movement -= up;
    }

    // movement = zm.vec.normalize(movement);
    const len = zm.vec.len(movement);
    if (len != 0) {
        movement = zm.vec.scale(movement, delta_time * player_speed / len);
        player_pos += movement;

        player_cam.updateView(player_pos);
    }
}

const Cam = struct {
    view: zm.Mat4f,
    proj: zm.Mat4f,

    yaw: f32,
    pitch: f32,

    dir: zm.Vec3f,
    right: zm.Vec3f,
    up: zm.Vec3f,

    fov: f32,

    fn rotate(cam: *Cam, pos: zm.Vec3f, yaw: f32, pitch: f32) void {
        cam.yaw += yaw;
        cam.pitch = m.clamp(cam.pitch + pitch, -89, 89);

        const yaw_radians = m.degreesToRadians(cam.yaw);
        const pitch_radians = m.degreesToRadians(cam.pitch);

        // From Learn OpenGL
        // TODO: replace this with a rotaion matrix (maybe switch to quaternions)
        cam.dir[0] = m.cos(yaw_radians) * m.cos(pitch_radians);
        cam.dir[1] = m.sin(pitch_radians);
        cam.dir[2] = m.sin(yaw_radians) * m.cos(pitch_radians);

        cam.dir = zm.vec.normalize(cam.dir);

        cam.right = zm.vec.normalize(zm.vec.cross(cam.dir, zm.vec.up(f32)));
        cam.up = zm.vec.normalize(zm.vec.cross(cam.right, cam.dir));

        cam.updateView(pos);
    }

    fn updateView(cam: *Cam, pos: zm.Vec3f) void {
        cam.view = zm.Mat4f.lookAt(pos, pos + cam.dir, cam.up).transpose();
    }

    fn updateProjection(cam: *Cam, width: u32, height: u32) void {
        cam.proj = zm.Mat4f.perspective(cam.fov, @as(f32, @floatFromInt(width)) / @as(f32, @floatFromInt(height)), 0.1, 1000).transpose();
    }

    fn init(fov: f32, pos: zm.Vec3f, width: u32, height: u32) Cam {
        var cam: Cam = .{ .view = zm.Mat4f.zero(), .proj = zm.Mat4f.zero(), .yaw = 90, .pitch = 0, .dir = zm.vec.zero(3, f32), .right = zm.vec.zero(3, f32), .up = zm.vec.zero(3, f32), .fov = m.degreesToRadians(fov) };

        cam.rotate(pos, 0, 0);
        cam.updateProjection(width, height);

        return cam;
    }
};
