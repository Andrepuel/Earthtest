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

    static SphericalCoordinate fromNormalized(CartesianCoordinate normalized) pure {
        import std.math;
        SphericalCoordinate result;
        result.rho = 1;
        result.theta = (normalized.z + 1)/2 * PI;
        result.phi = (normalized.x + 1)/2 * PI * 2;
        return result;
    }

    SphericalCoordinate toDegree() const pure {
        import std.math;
        return SphericalCoordinate(phi*180/PI, theta*180/PI, rho);
    }

    SphericalCoordinate rotX(double theta) const pure {
        return toCartesian.rotX(theta).toSpherical();
    }
    SphericalCoordinate rotY(double theta) const pure {
        return toCartesian.rotY(theta).toSpherical();
    }
    SphericalCoordinate rotZ(double theta) const pure {
        return toCartesian.rotZ(theta).toSpherical();
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
        if (result.phi < 0.0) result.phi += 2*PI;
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

    CartesianCoordinate rotX(double theta) const pure {
        import std.math;
        double cosT = theta.cos;
        double sinT = theta.sin;

        return CartesianCoordinate(x, y * cosT + z * sinT, -y * sinT + z * cosT);
    }
    CartesianCoordinate rotY(double theta) const pure {
        import std.math;
        double cosT = theta.cos;
        double sinT = theta.sin;

        return CartesianCoordinate(x * cosT + z * sinT, y, -x * sinT + z * cosT);
    }
    CartesianCoordinate rotZ(double theta) const pure {
        import std.math;
        double cosT = theta.cos;
        double sinT = theta.sin;

        return CartesianCoordinate(x * cosT + y * sinT, -x * sinT + y * cosT, z);
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

unittest {
    import std.exception;
    import std.format;
    import std.math;

    foreach(theta; 1..31) {
        foreach(phi; 1..63) {
            SphericalCoordinate a;
            a.rho = 1;
            a.theta = theta/10.0;
            a.phi = phi/10.0;

            CartesianCoordinate b = a.toCartesian;
            SphericalCoordinate c = b.toSpherical;
            enforce(abs(a.rho - c.rho) <= 0.1, format("%s %s %s", a, b, c));
            enforce(abs(a.theta - c.theta) <= 0.1, format("%s %s %s", a, b, c));
            enforce(abs(a.phi - c.phi) <= 0.1, format("%s %s %s", a, b, c));
        }
    }
}
