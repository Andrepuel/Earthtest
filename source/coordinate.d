module coordinate;

double clamp(double what, double min, double max) pure {
    if (what < min) return min;
    if (what > max) return max;
    return what;
}

int clamp(int what, int min, int max) pure {
    if (what < min) return min;
    if (what > max) return max;
    return what;
}

struct SphericalCoordinate {
    // From 0 to 2*PI
    double phi;
    // From 0 to PI
    double theta;
    double rho;

    CartesianCoordinate toCartesian() const pure {
        import std.math;
        CartesianCoordinate result;
        result.x = rho * sin(theta) * cos(phi);
        result.y = rho * sin(theta) * sin(phi);
        result.z = rho * cos(theta);
        return result;
    }

    CartesianCoordinate normalize() const pure {
        import std.math;
        CartesianCoordinate result;
        result.x = (phi/(2*PI)) * 2 - 1;
        result.x.clamp(-1, 1);
        result.z = (theta/PI) * 2 - 1;
        result.z.clamp(-1, 1);
        result.fixY();
        result.y.clamp(-1, 1);
        return result;
    }

    SphericalCoordinate toDegree() const pure {
        import std.math;
        return SphericalCoordinate(phi*180/PI, theta*180/PI, rho);
    }
}

struct CartesianCoordinate {
    double x;
    double y;
    double z;

    SphericalCoordinate toSpherical() const pure {
        import std.math;
        SphericalCoordinate result;
        result.rho = sqrt(x*x + y*y + z*z);
        result.theta = acos(z/result.rho);
        result.phi = atan2(y, x);
        return result;
    }

    ImageCoordinate toImage(int w, int h) const pure {
        ImageCoordinate result;
        result.x = cast(int) ((x + 1)*(w-1) / 2);
        result.y = cast(int) ((z + 1)*(h-1) / 2);
        result.w = w;
        result.h = h;
        result.x = result.x.clamp(0, w-1);
        result.y = result.y.clamp(0, h-1);
        return result;
    }

    void fixY(double rho = 1) pure {
        import std.math;
        y = sqrt(rho * rho - x*x - z*z);
    }
}

struct ImageCoordinate {
    int x;
    int y;
    int w;
    int h;

    CartesianCoordinate normalize(double rho = 1) const pure {
        import std.math;
        CartesianCoordinate result;
        result.x = (cast(double)x*2)/w - 1;
        result.z = (cast(double)y*2)/h - 1;
        result.fixY(rho);
        return result;
    }
}
