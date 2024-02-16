const std = @import("std");
const log = std.log;
const os = std.os;

const udev = @import("udev");

const Event = @import("../EventLoop.zig").Event;
const render = @import("../render.zig");
const utils = @import("../utils.zig");

const Battery = @This();

const context = &@import("root").context;

ucontext: *udev.Udev,
devices: DeviceList,

const Device = struct {
    name: []const u8,
    status: []const u8,
    capacity: u8,
};

const DeviceList = std.ArrayList(Device);

pub fn init() !Battery {
    const ucontext = try udev.Udev.new();

    var devices = DeviceList.init(context.gpa);
    try updateDevices(context.gpa, ucontext, &devices);

    return Battery{
        .ucontext = ucontext,
        .devices = devices,
    };
}

pub fn deinit(self: *Battery) void {
    _ = self.ucontext.unref();
    for (self.devices.items) |*device| {
        context.gpa.free(device.name);
        context.gpa.free(device.status);
    }
    self.devices.deinit();
}

pub fn print(self: *Battery) !void {
    try updateDevices(context.gpa, self.ucontext, &self.devices);
    const device = self.devices.items[0];

    var string = std.ArrayList(u8).init(context.gpa);
    defer string.deinit();

    if (std.mem.eql(u8, "Charging", device.status)) {
        try std.fmt.format(string.writer(), "CHARGING {d}%", .{device.capacity});
    } else {
        try std.fmt.format(string.writer(), "BAT {d}%", .{device.capacity});
    }

    for (context.wayland.monitors.items) |monitor| {
        if (monitor.bar) |bar| {
            if (bar.configured) {
                try render.renderWidget(bar, &bar.battery, string.items, 1);
                bar.battery.surface.commit();
                bar.audio.surface.commit();
                bar.background.surface.commit();
            }
        }
    }
}

pub fn refresh(self: *Battery) !void {
    self.print() catch return;
}

fn updateDevices(
    gpa: std.mem.Allocator,
    ucontext: *udev.Udev,
    devices: *DeviceList,
) !void {
    const enumerate = try udev.Enumerate.new(ucontext);
    defer _ = enumerate.unref();

    try enumerate.addMatchSubsystem("power_supply");
    try enumerate.addMatchSysattr("type", "Battery");
    try enumerate.scanDevices();

    const entries = enumerate.getListEntry();

    var maybe_entry = entries;
    while (maybe_entry) |entry| : (maybe_entry = entry.getNext()) {
        const path = entry.getName();
        const device = try udev.Device.newFromSyspath(ucontext, path);
        try updateOrAppend(gpa, devices, device);
    }
}

fn updateOrAppend(
    gpa: std.mem.Allocator,
    devices: *DeviceList,
    dev: *udev.Device,
) !void {
    const name = dev.getSysname() catch return;
    const status = dev.getSysattrValue("status") catch return;
    const capacity = getCapacity(dev) catch return;

    const device = blk: {
        for (devices.items) |*device| {
            if (std.mem.eql(u8, device.name, name)) {
                gpa.free(device.status);
                break :blk device;
            }
        } else {
            const device = try devices.addOne();
            device.name = try gpa.dupe(u8, name);
            break :blk device;
        }
    };

    device.status = try gpa.dupe(u8, status);
    device.capacity = capacity;
}

fn getCapacity(dev: *udev.Device) !u8 {
    const capacity_str = try dev.getSysattrValue("capacity");

    const capacity = try std.fmt.parseInt(u8, capacity_str, 10);
    return capacity;
}
