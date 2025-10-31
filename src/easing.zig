// Copied from: https://github.com/Games-by-Mason/Tween/blob/main/src/ease.zig

pub fn smootherstep(t: f32) f32 {
    const t3 = t * t * t;
    const t4 = t3 * t;
    const t5 = t4 * t;
    return @mulAdd(f32, 6, t5, @mulAdd(f32, -15.0, t4, 10.0 * t3));
}

fn quadInOut(t: f32) f32 {
    if (t < 0.5) {
        return 2 * t * t;
    } else {
        return @mulAdd(f32, 4, t, -1) - 2 * t * t;
    }
}
