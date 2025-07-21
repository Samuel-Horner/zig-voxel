const std = @import("std");
const m = std.math;

const zm = @import("zm");

const debug = @import("debug.zig");
const engine = @import("engine/engine.zig");

var player_pos: zm.Vec3f = undefined;
var player_cam: Cam = undefined;

var player_speed: f32 = undefined;
var player_sensitivity: f32 = undefined;

// ##### Uniform Getters #####
pub fn getView() zm.Mat4f {
    return zm.Mat4f.lookAt(player_pos, player_pos + player_cam.dir, player_cam.up);
}

pub fn getProj() zm.Mat4f {
    return player_cam.proj;
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
        @as(f32, @floatCast(xpos - prev_xpos)) * player_sensitivity, 
        -@as(f32, @floatCast(ypos - prev_ypos)) * player_sensitivity
    );

    prev_xpos = xpos;
    prev_ypos = ypos;

    log();
}

// ##### General Player Functions #####
pub fn init(starting_pos: zm.Vec3f, speed: f32, sensitivity: f32, fov: f32) void {
    player_speed = speed;
    player_sensitivity = sensitivity;

    player_pos = starting_pos;
    player_cam.updateProjection();
    player_cam = Cam.init(fov);

    engine.window.setCursorPosCallback(cursorCallback);
}

pub fn tick(delta_time: f32) void {
    var movement: zm.Vec3f = zm.vec.zero(3, f32);

    if (engine.keyPressed(engine.Key.w)) {
        movement += player_cam.dir;
    }
    if (engine.keyPressed(engine.Key.s)) {
        movement -= player_cam.dir;
    }
    if (engine.keyPressed(engine.Key.d)) {
        movement += player_cam.right;
    }
    if (engine.keyPressed(engine.Key.a)) {
        movement -= player_cam.right;
    }

    // movement = zm.vec.normalize(movement);
    const len = zm.vec.len(movement);
    if (len != 0) {
        movement = zm.vec.scale(movement, delta_time * player_speed / len);
        player_pos += movement;
        log();
    }
}

pub fn log() void {
    debug.log("POS: {d:.3}", .{player_pos});
    debug.log("DIR: {d:.3}", .{player_cam.dir});
    debug.log("PROJ: {d:.3}", .{getProj().data});
    debug.log("VIEW: {d:.3}", .{getView().data});
}

const Cam = struct {
    proj: zm.Mat4f,

    yaw: f32,
    pitch: f32,

    dir: zm.Vec3f,
    right: zm.Vec3f,
    up: zm.Vec3f,

    fov: f32,

    fn rotate(cam: *Cam, yaw: f32, pitch: f32) void {
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

        debug.log("LENS: {} {}", .{zm.vec.len(cam.right), zm.vec.len(cam.up)});
    }

    fn updateProjection(cam: *Cam) void {
        debug.log("Updating camera perspective with width / height: {}x{}", .{engine.window_width, engine.window_height});
        cam.proj = zm.Mat4f.perspective(
            cam.fov, 
            @as(f32, @floatFromInt(engine.window_width)) / @as(f32, @floatFromInt(engine.window_height)), 
            0.1, 
            1000
        );
    }

    fn init(fov: f32) Cam {
        var cam: Cam = .{
            .proj = zm.Mat4f.zero(),

            .yaw = 90,
            .pitch = 0,

            .dir = zm.vec.zero(3, f32),
            .right = zm.vec.zero(3, f32),
            .up = zm.vec.zero(3, f32),

            .fov = m.degreesToRadians(fov)
        };

        cam.rotate(0, 0);
        cam.updateProjection();

        return cam;
    }
};
