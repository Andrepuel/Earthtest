module interpolate;

private {
    import std.math;
    struct CoordinateD {
        double x;
        double y;

        CoordinateI floorMult(int multX, int multY) {
            return CoordinateI(cast(int) floor(x * multX), cast(int) floor(y * multY));
        }

        CoordinateI ceilMult(int multX, int multY) {
            return CoordinateI(cast(int) ceil(x * multX), cast(int) ceil(y * multY));
        }

        CoordinateD decimal(int multX, int multY) {
            CoordinateD result = CoordinateD(x * multX, y * multY);
            result.x -= floor(result.x);
            result.y -= floor(result.y);
            return result;
        }
    }
}

struct Grid {
    int w;
    int h;
    double[] data;

    double[] opIndex(ptrdiff_t i) {
        return data[i*w..(i+1)*w];
    }
};

struct CoordinateI {
    int x;
    int y;
}

double interpolate(double x, double y, Grid grid) {
    CoordinateD xy;
    xy.x = (x + 1) / 2;
    xy.y = (y + 1) / 2;
    CoordinateI lower = xy.floorMult(grid.h - 1, grid.w - 1);
    CoordinateI upper = xy.ceilMult(grid.h - 1, grid.w - 1);
    xy = xy.decimal(grid.h - 1, grid.w - 1);

    double lowerValue = interpolate(xy.x, grid[lower.y][lower.x], grid[lower.y][upper.x]);
    double upperValue = interpolate(xy.x, grid[upper.y][lower.x], grid[upper.y][upper.x]);
    return interpolate(xy.y, lowerValue, upperValue);
}

double interpolate(double t, double lower, double upper) {
    return lower * (1 - t) + upper * t;
}
