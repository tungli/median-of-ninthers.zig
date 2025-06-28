const std = @import("std");

pub fn QuickSelect(comptime T: type) type {
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
            const q = @This(){ .items = self.items[0..j] };
            q.kthElement(.bfprt_baseline, j / 2);
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
            const q = @This(){ .items = self.items[0..m] };
            q.kthElement(.repeated_step, m / 2);
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
            const a = @This() { .items = inds }; // just for swaps
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

        pub fn medianOfNinthers(self: @This()) usize {
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
                x.kthElement(.median_of_ninthers, p);
                return self.expandPartition(low, low + p, high);
            } else {
                x.kthElement(.repeated_step, p);
                return self.hoarePartition(p);
            }
        }

        pub fn kthElement(
            self: @This(),
            comptime method: PartitionMethod,
            k: usize,
        ) void {
            const partition = switch (method) {
                .bfprt_baseline => BFPRTBaseline,
                .repeated_step => repeatedStep,
                .median_of_ninthers => medianOfNinthers,
            };

            var cur = self.items;
            var i = k;
            while (true) {
                const q = @This(){ .items = cur };
                const p = partition(q);
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

test "baseline" {
    // 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 9, 10, 11
    var data = [_]usize{ 1, 11, 5, 10, 6, 7, 4, 2, 3, 2, 5, 4, 9 };

    const q = QuickSelect(usize){ .items = &data };

    var k = data.len / 2;
    q.kthElement(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 5);

    k = 0;
    q.kthElement(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 1);

    k = 1;
    q.kthElement(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 2);

    k = 2;
    q.kthElement(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 2);

    k = 3;
    q.kthElement(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 3);

    k = data.len - 2;
    q.kthElement(.bfprt_baseline, k);
    try std.testing.expect(data[k] == 10);
}

test "repeated step" {
    // 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 9, 10, 11
    var data = [_]usize{ 1, 11, 5, 10, 6, 7, 4, 2, 3, 2, 5, 4, 9 };

    const q = QuickSelect(usize){ .items = &data };

    var k = data.len / 2;
    q.kthElement(.repeated_step, k);
    try std.testing.expect(data[k] == 5);

    k = 0;
    q.kthElement(.repeated_step, k);
    try std.testing.expect(data[k] == 1);

    k = 1;
    q.kthElement(.repeated_step, k);
    try std.testing.expect(data[k] == 2);

    k = 2;
    q.kthElement(.repeated_step, k);
    try std.testing.expect(data[k] == 2);

    k = 3;
    q.kthElement(.repeated_step, k);
    try std.testing.expect(data[k] == 3);

    k = data.len - 2;
    q.kthElement(.repeated_step, k);
    try std.testing.expect(data[k] == 10);
}

test "ninthers median" {
    // 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 9, 10, 11
    var data = [_]usize{ 1, 11, 5, 10, 6, 7, 4, 2, 3, 2, 5, 4, 9 };

    const q = QuickSelect(usize){ .items = &data };

    var k = data.len / 2;
    q.kthElement(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 5);

    k = 0;
    q.kthElement(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 1);

    k = 1;
    q.kthElement(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 2);

    k = 2;
    q.kthElement(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 2);

    k = 3;
    q.kthElement(.median_of_ninthers, k);
    try std.testing.expect(data[k] == 3);

    k = data.len - 2;
    q.kthElement(.median_of_ninthers, k);
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

    const q = QuickSelect(usize){ .items = y };
    const k = y.len / 2;
    q.kthElement(.median_of_ninthers, k);
    std.debug.print("{}\n", .{y[k]});
    try std.testing.expect(y[k] == 515);
}



