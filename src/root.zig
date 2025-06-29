//! This version is written based on the original work:
//!    [MedianOfNithers](https://github.com/andralex/MedianOfNinthers)
//! and associated paper:
//!    ["Fast Deterministic Selection" by Andrei Alexandrescu](https://erdani.org/research/sea2017.pdf)
//! with license:
//! ```
//! ------------------------------------------------------------
//!          Copyright Andrei Alexandrescu, 2016-.
//! Distributed under the Boost Software License, Version 1.0.
//!    (See accompanying file LICENSE_1_0.txt or copy at
//!          https://boost.org/LICENSE_1_0.txt)
//! ------------------------------------------------------------
//! ```
//! 
//! Example usage:
//! ```
//! var data = [_]usize{ 1, 11, 5, 10, 6, 7, 4, 2, 3, 2, 5, 4, 9 };
//! const x = Partition(usize){ .items = &data };
//! const k = data.len / 2;
//! x.kElement(k);
//! const median = x[k]; // 5
//! ```


const std = @import("std");

pub fn Partition(comptime T: type) type {
    return struct {
        items: []T,

        pub const PartitionMethod = enum {
            bfprt_baseline,
            repeated_step,
            median_of_ninthers,
        };

        fn swap(self: @This(), a: usize, b: usize) void {
            return std.mem.swap(T, &self.items[a], &self.items[b]);
        }

        fn median5(self: @This(), a: usize, b: usize, c: usize, d: usize, e: usize) void {
            const x = self.items;
            if (x[a] > x[b]) self.swap(a, b);
            if (x[d] > x[e]) self.swap(d, e);

            if (x[c] > x[e]) self.swap(c, e);
            if (x[c] > x[d]) self.swap(c, d);
            if (x[b] > x[e]) self.swap(b, e);

            if (x[a] > x[d]) self.swap(a, d);
            if (x[b] > x[c]) self.swap(b, c);
        }

        fn hoarePartition(self: @This(), p: usize) usize {
            self.swap(p, 0);
            var a: usize = 1;
            var b: usize = self.items.len - 1;

            loop: {
                while (true) {
                    while (true) {
                        if (a > b) break :loop;
                        if (self.items[a] >= self.items[0]) break;
                        a += 1;
                    }
                    while (self.items[0] < self.items[b]) {
                        b -= 1;
                    }
                    if (a >= b) break;
                    self.swap(a, b);
                    a += 1;
                    b -= 1;
                }
            }

            self.swap(0, a - 1);
            return a - 1;
        }

        fn BFPRTBaseline(self: @This()) usize {
            if (self.items.len < 5) {
                return self.hoarePartition(self.items.len / 2);
            }
            var i: usize = 0;
            var j: usize = 0;
            while (i + 4 < self.items.len) {
                self.median5(i, i + 1, i + 2, i + 3, i + 4);
                self.swap(i + 2, j);
                i += 5;
                j += 1;
            }
            const x = @This(){ .items = self.items[0..j] };
            x.kthElementMethod(.bfprt_baseline, j / 2);
            return self.hoarePartition(j / 2);
        }

        fn median3(self: @This(), a: usize, b: usize, c: usize) void {
            const x = self.items;
            if (x[b] < x[a]) {
                if (x[b] < x[c]) {
                    if (x[c] < x[a]) {
                        self.swap(b, c);
                    } else {
                        self.swap(b, a);
                    }
                }
            } else if (x[c] < x[b]) {
                if (x[c] < x[a]) {
                    self.swap(b, a);
                } else {
                    self.swap(b, c);
                }
            }
        }

        fn repeatedStep(self: @This()) usize {
            if (self.items.len < 9) return self.hoarePartition(self.items.len / 2);
            var i: usize = 0;
            var j: usize = 0;
            while (i + 2 < self.items.len) {
                self.median3(i, i + 1, i + 2);
                self.swap(i + 1, j);
                i += 3;
                j += 1;
            }
            i = 0;
            var m: usize = 0;
            while (i + 2 < j) {
                self.median3(i, i + 1, i + 2);
                self.swap(i + 1, m);
                i += 3;
                m += 1;
            }
            const x = @This(){ .items = self.items[0..m] };
            x.kthElementMethod(.repeated_step, m / 2);
            return self.hoarePartition(m / 2);
        }

        fn expandPartitionRight(self: @This(), a: usize, b: usize) usize {
            var p: usize = 0;
            var j: usize = b;

            loops: {
                while (p < a) : (j -= 1) {
                    if (j == a) break :loops;
                    if (self.items[j] >= self.items[0]) continue;
                    p += 1;
                    self.swap(j, p);
                }

                while (j > p) : (j -= 1) {
                    if (self.items[j] >= self.items[0]) continue;
                    while (j > p) {
                        p += 1;
                        if (self.items[0] < self.items[p]) {
                            self.swap(j, p);
                            break;
                        }
                    }
                }
            }
            self.swap(0, p);
            return p;
        }

        fn expandPartitionLeft(self: @This(), a: usize, orig_pivot: usize) usize {
            var p = orig_pivot;
            var i: usize = 0;

            loops: {
                while (a < p) : (i += 1) {
                    if (i == a) break :loops;
                    if (self.items[orig_pivot] >= self.items[i]) continue;
                    p -= 1;
                    self.swap(i, p);
                }

                while (true) : (i += 1) {
                    if (i == p) break;
                    if (self.items[orig_pivot] >= self.items[i]) continue;
                    while (true) {
                        if (i == p) break :loops;
                        p -= 1;
                        if (self.items[p] < self.items[orig_pivot]) {
                            self.swap(i, p);
                            break;
                        }
                    }
                }
            }

            self.swap(orig_pivot, p);
            return p;
        }

        fn expandPartition(self: @This(), a: usize, p: usize, b: usize) usize {
            var len = self.items.len - 1;
            const i = b - 1;
            var j: usize = 0;
            while (true) : ({
                j += 1;
                len -= 1;
            }) {
                while (true) : (j += 1) {
                    const x = @This(){ .items = self.items[p..self.items.len] };
                    if (j == a) return p + x.expandPartitionRight(i - p, len - p);
                    if (self.items[j] > self.items[p]) break;
                }

                while (true) : (len -= 1) {
                    if (len == i) {
                        const x = @This(){ .items = self.items[j..self.items.len] };
                        return j + x.expandPartitionLeft(a - j, p - j);
                    }
                    if (self.items[p] >= self.items[len]) break;
                }
                self.swap(j, len);
            }
        }

        fn medianIndex(self: @This(), a: usize, b: usize, c: usize) usize
        {
            const x = self.items;

            if (x[a] > x[c]) {
                if (x[b] > x[a]) {
                    return a;
                }
                if (x[b] < x[c]) {
                    return c;
                }
            } else {
                if (x[b] > x[c]) {
                    return c;
                }
                if (x[b] < x[a]) {
                    return a;
                }
            }
            return b;
        }

        fn ninther(
            self: @This(),
            inds: *[9]usize
        ) void {
            const x = self.items;
            const a = Partition(usize) { .items = inds }; // just for swaps
            inds[1] = self.medianIndex(inds[0], inds[1], inds[2]);
            inds[7] = self.medianIndex(inds[6], inds[7], inds[8]);
            if (x[inds[1]] > x[inds[7]]) a.swap(1, 7);
            if (x[inds[3]] > x[inds[6]]) a.swap(3, 5);
            if ((x[inds[4]] < x[inds[3]]) and (x[inds[4]] > x[inds[5]])) {
                inds[3] = inds[5];
            } else {
                if (x[inds[4]] < x[inds[1]]) {
                    self.swap(inds[4], inds[1]);
                    return;
                }
                if (x[inds[4]] > x[inds[7]]) {
                    self.swap(inds[4], inds[7]);
                    return;
                }
                return;
            }
            if (x[inds[3]] < x[inds[1]]) {
                inds[3] = inds[1];
            } else if (x[inds[3]] > x[inds[7]]) {
                inds[3] = inds[7];
            }
            self.swap(inds[4], inds[3]);
        }

        fn medianOfNinthers(self: @This()) usize {
            const len = self.items.len;
            // std.debug.assert(len > 11);

            const phi = if (len <= 1024) len / 12 else
                if(len <= 128 * 1024) len / 64 else len / 1024;

            const p = phi / 2;
            const low = len / 2 - p;
            const high = low + phi;

            const gap = (len - 9 * phi) / 4;
            var a = low - 4 * phi - gap;
            var b = high + gap;
            for (low..high) |i| {
                var inds = [9]usize {a, i - phi, b, a + 1, i, b + 1, a + 2, i + phi, b + 2};
                self.ninther(&inds);
                a += 3;
                b += 3;
            }

            const x = @This() { .items = self.items[low..len] };
            x.kthElement(p);
            return self.expandPartition(low, low + p, high);
        }

        fn medianOfNinthersMethod(self: @This()) usize {
            const len = self.items.len;
            // std.debug.assert(len > 11);

            const phi = if (len <= 1024) len / 12 else
                if(len <= 128 * 1024) len / 64 else len / 1024;

            const p = phi / 2;
            const low = len / 2 - p;
            const high = low + phi;

            const gap = (len - 9 * phi) / 4;
            var a = low - 4 * phi - gap;
            var b = high + gap;
            for (low..high) |i| {
                var inds = [9]usize {a, i - phi, b, a + 1, i, b + 1, a + 2, i + phi, b + 2};
                self.ninther(&inds);
                a += 3;
                b += 3;
            }

            const x = @This() { .items = self.items[low..len] };
            if (x.items.len > 11) {
                x.kthElementMethod(.median_of_ninthers, p);
                return self.expandPartition(low, low + p, high);
            } else {
                x.kthElementMethod(.repeated_step, p);
                return self.hoarePartition(p);
            }
        }

        pub fn kthElementMethod(
            self: @This(),
            comptime method: PartitionMethod,
            k: usize,
        ) void {
            const partition = switch (method) {
                .bfprt_baseline => BFPRTBaseline,
                .repeated_step => repeatedStep,
                .median_of_ninthers => medianOfNinthersMethod,
            };

            var cur = self.items;
            var i = k;
            while (true) {
                const x = @This(){ .items = cur };
                const p = partition(x);
                if (p == i) return;
                if (p > i) {
                    cur = cur[0..p];
                } else {
                    i -= p + 1;
                    cur = cur[(p + 1)..cur.len];
                }
            }
        }

        fn medianOfMinima(self: @This(), k: usize) usize {
            const k2 = k * 2;
            const min_over = self.items.len / k2;
            var j = k2;
            for (0..k2) |i| {
                const limit = j + min_over;
                var min_index = j;
                while(true)
                {
                    j += 1;
                    if (j < limit) break;
                    if (self.items[j] < self.items[min_index]) {
                        min_index = j;
                    }
                }
                if (self.items[min_index] < self.items[i]) {
                    self.swap(i, min_index);
                }
            }
            const x = @This() { .items = self.items[0..k2] };
            x.kthElement(k);
            return self.expandPartition(0, k, k2);
        }

        fn medianOfMaxima(self: @This(), k: usize) usize {
            const len = self.items.len;
            const subset = (len - k) * 2;
            const start = len - subset;
            const max_over = start / subset;

            var j = start - subset * max_over;
            for (start..len) |i| {
                const limit = j + max_over;
                var max_index = j;
                while( true) {
                    j += 1;
                    if (j < limit) break;
                    if (self.items[j] > self.items[max_index]) {
                        max_index = j;
                    }
                }
                if (self.items[max_index] > self.items[i]) {
                    self.swap(i, max_index);
                }
            }
            const x = @This() { .items = self.items[start..len] };
            x.kthElement(len - k);
            return self.expandPartition(start, k, len);
        }

        /// Rearranges the `self.items` such that `self.items[k]` will be at
        /// the same position were the slice sorted. Furthermore, all elements
        /// `self.items[0..k]` are less or equal to `self.items[k]` and all
        /// elements `self.items[k..self.items.len]` are greater or equal to
        /// `self.items[k]`.
        pub fn kthElement(self: @This(), k: usize) void {
            var cur = self.items;
            var i = k;
            while(true) {
                if (i == 0)
                {
                    var p = i;
                    for ((i+1)..cur.len) |n| {
                        if (cur[n] < cur[p]) {
                            p = n;
                        }
                    }
                    self.swap(0, p);
                    return;
                }
                if (i + 1 == cur.len)
                {
                    var p: usize = 0;
                    for (1..cur.len) |n| {
                        if (cur[p] < cur[n]) {
                            p = n;
                        }
                    }
                    self.swap(cur.len - 1, p);
                    return;
                }

                const x = @This() { .items = cur };
                var p: usize = undefined;
                if (cur.len < 17) {
                    p = x.hoarePartition(i);
                }
                else if (i * 6 <= cur.len) {
                    p = x.medianOfMinima(i);
                } else if (i * 6 >= cur.len * 5) {
                    p = x.medianOfMaxima(i);
                } else {
                    p = x.medianOfNinthers();
                }

                if (p == i) return;
                if (p > i) {
                    cur = cur[0..p];
                } else {
                    i -= p + 1;
                    cur = cur[(p + 1)..cur.len];
                }
            }
        }
    };
}


// Export functions for C library

fn kth_element_generic(T: type, ptr: [*]T, len: usize, k: usize) void {
    var slice: []T = undefined;
    slice.ptr = ptr;
    slice.len = len;
    const x = Partition(T) { .items = slice };
    x.kthElement(k);

}


pub export fn kth_element_char(ptr: [*]c_char, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_char, ptr, len, k);
}

pub export fn kth_element_short(ptr: [*]c_short, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_short, ptr, len, k);
}

pub export fn kth_element_int(ptr: [*]c_int, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_int, ptr, len, k);
}

pub export fn kth_element_long(ptr: [*]c_long, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_long, ptr, len, k);
}

pub export fn kth_element_longlong(ptr: [*]c_longlong, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_longlong, ptr, len, k);
}

pub export fn kth_element_uint(ptr: [*]c_uint, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_uint, ptr, len, k);
}

pub export fn kth_element_ushort(ptr: [*]c_ushort, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_ushort, ptr, len, k);
}

pub export fn kth_element_ulong(ptr: [*]c_ulong, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_ulong, ptr, len, k);
}

pub export fn kth_element_ulonglong(ptr: [*]c_ulonglong, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_ulonglong, ptr, len, k);
}

pub export fn kth_element_float(ptr: [*]f32, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(f32, ptr, len, k);
}

pub export fn kth_element_double(ptr: [*]f64, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(f64, ptr, len, k);
}

pub export fn kth_element_longdouble(ptr: [*]c_longdouble, len: usize, k: usize) callconv(.C) void {
    return kth_element_generic(c_longdouble, ptr, len, k);
}




test "baseline" {
    // 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 9, 10, 11
    var data = [_]usize{ 1, 11, 5, 10, 6, 7, 4, 2, 3, 2, 5, 4, 9 };

    const x = Partition(usize){ .items = &data };

    var k = data.len / 2;
    x.kthElementMethod(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 5);

    k = 0;
    x.kthElementMethod(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 1);

    k = 1;
    x.kthElementMethod(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 2);

    k = 2;
    x.kthElementMethod(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 2);

    k = 3;
    x.kthElementMethod(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 3);

    k = data.len - 2;
    x.kthElementMethod(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 10);
}

test "repeated step" {
    // 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 9, 10, 11
    var data = [_]usize{ 1, 11, 5, 10, 6, 7, 4, 2, 3, 2, 5, 4, 9 };

    const x = Partition(usize){ .items = &data };

    var k = data.len / 2;
    x.kthElementMethod(.repeated_step, k);
    try std.testing.expect(data[k] == 5);

    k = 0;
    x.kthElementMethod(.repeated_step, k);
    try std.testing.expect(data[k] == 1);

    k = 1;
    x.kthElementMethod(.repeated_step, k);
    try std.testing.expect(data[k] == 2);

    k = 2;
    x.kthElementMethod(.repeated_step, k);
    try std.testing.expect(data[k] == 2);

    k = 3;
    x.kthElementMethod(.repeated_step, k);
    try std.testing.expect(data[k] == 3);

    k = data.len - 2;
    x.kthElementMethod(.repeated_step, k);
    try std.testing.expect(data[k] == 10);
}

test "ninthers median" {
    // 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 9, 10, 11
    var data = [_]usize{ 1, 11, 5, 10, 6, 7, 4, 2, 3, 2, 5, 4, 9 };

    const x = Partition(usize){ .items = &data };

    var k = data.len / 2;
    x.kthElementMethod(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 5);

    k = 0;
    x.kthElementMethod(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 1);

    k = 1;
    x.kthElementMethod(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 2);

    k = 2;
    x.kthElementMethod(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 2);

    k = 3;
    x.kthElementMethod(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 3);

    k = data.len - 2;
    x.kthElementMethod(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 10);
}

test "rng data" {
    const gpa = std.testing.allocator;
    const n: usize = 10000;
    const y = try gpa.alloc(usize, n);
    defer gpa.free(y);
    var a: usize = 131;
    for (0..n) |i| {
         a = (85151 * a + 191) % 1031;
         y[i] = a;
    }

    const x = Partition(usize){ .items = y };
    const k = y.len / 2;
    x.kthElementMethod(.median_of_ninthers, k);
    try std.testing.expect(y[k] == 515);
}

test "rng data2" {
    const gpa = std.testing.allocator;
    const n: usize = 10000;
    const y = try gpa.alloc(usize, n);
    defer gpa.free(y);
    var a: usize = 131;
    for (0..n) |i| {
         a = (85151 * a + 191) % 1031;
         y[i] = a;
    }

    const x = Partition(usize){ .items = y };
    const k = y.len / 2;
    x.kthElement(k);
    try std.testing.expect(y[k] == 515);

    const kth = y[k]; 
    for (0..k) |i| {
        try std.testing.expect(kth >= y[i]);
    }

    for (k..y.len) |i| {
        try std.testing.expect(kth <= y[i]);
    }
}
