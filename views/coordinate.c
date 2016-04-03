#ifndef __OPENCL_VERSION__
#include <math.h>
float clamp(float v, float a, float b) {
    if (v < a) return a;
    if (v > b) return b;
    return v;
}
#else
#define M_PI 3.1415926536f
#endif

struct ImageCoordinate {
    int x, y, w, h;
};
struct CartesianCoordinate {
    float x, y, z;
};
struct SphericalCoordinate {
    // From 0 to 2*PI
    float phi;
    // From 0 to PI
    float theta;
    float rho;
};
struct CartesianCoordinate ImageCoordinate_normalize(struct ImageCoordinate* self, float rho);

void CartesianCoordinate_fixY(struct CartesianCoordinate* self, float rho);
struct SphericalCoordinate CartesianCoordinate_toSpherical(struct CartesianCoordinate* self);
struct ImageCoordinate CartesianCoordinate_toImage(struct CartesianCoordinate* self, int w, int h);
struct CartesianCoordinate CartesianCoordinate_rotX(struct CartesianCoordinate* self, float theta);
struct CartesianCoordinate CartesianCoordinate_rotY(struct CartesianCoordinate* self, float theta);
struct CartesianCoordinate CartesianCoordinate_rotZ(struct CartesianCoordinate* self, float theta);

struct CartesianCoordinate SphericalCoordinate_toCartesian(struct SphericalCoordinate* self);
struct CartesianCoordinate SphericalCoordinate_normalize(struct SphericalCoordinate* self);
struct SphericalCoordinate SphericalCoordinate_fromNormalized(struct CartesianCoordinate normalized);

struct CartesianCoordinate SphericalCoordinate_toCartesian(struct SphericalCoordinate* self) {
    struct CartesianCoordinate result;
    result.x = self->rho * sin(self->theta) * cos(self->phi);
    result.y = self->rho * sin(self->theta) * sin(self->phi);
    result.z = self->rho * cos(self->theta);
    return result;
}

void CartesianCoordinate_fixY(struct CartesianCoordinate* self, float rho) {
    self->y = sqrt(rho * rho - self->x*self->x - self->z*self->z);
}

struct CartesianCoordinate SphericalCoordinate_normalize(struct SphericalCoordinate* self) {
    struct CartesianCoordinate result;
    result.x = clamp((self->phi/(2*M_PI)) * 2 - 1, -1.0f, 1.0f);
    result.z = clamp((self->theta/M_PI) * 2 - 1, -1.0f, 1.0f);
    CartesianCoordinate_fixY(&result, 1.0f);
    result.y = clamp(result.y, -1.0f, 1.0f);
    return result;
}

struct SphericalCoordinate CartesianCoordinate_toSpherical(struct CartesianCoordinate* self) {
    struct SphericalCoordinate result;
    result.rho = sqrt(self->x*self->x + self->y*self->y + self->z*self->z);
    result.theta = acos(self->z/result.rho);
    result.phi = atan2(self->y, self->x);
    if (result.phi < 0.0f) result.phi += 2*M_PI;
    return result;
}

struct ImageCoordinate CartesianCoordinate_toImage(struct CartesianCoordinate* self, int w, int h) {
    struct ImageCoordinate result;
    result.x = (int) ((self->x + 1)*(w-1) / 2);
    result.y = (int) ((self->z + 1)*(h-1) / 2);
    result.w = w;
    result.h = h;
    result.x = clamp(result.x, 0, w-1);
    result.y = clamp(result.y, 0, h-1);
    return result;
}

struct CartesianCoordinate CartesianCoordinate_rotX(struct CartesianCoordinate* self, float theta) {
    float cosT = cos(theta);
    float sinT = sin(theta);

    struct CartesianCoordinate result;
    result.x = self->x;
    result.y = self->y * cosT + self->z * sinT;
    result.z = -self->y * sinT + self->z * cosT;
    return result;
}
struct CartesianCoordinate CartesianCoordinate_rotY(struct CartesianCoordinate* self, float theta) {
    float cosT = cos(theta);
    float sinT = sin(theta);

    struct CartesianCoordinate result;
    result.x = self->x * cosT + self->z * sinT;
    result.y = self->y;
    result.z = -self->x * sinT + self->z * cosT;
    return result;
}
struct CartesianCoordinate CartesianCoordinate_rotZ(struct CartesianCoordinate* self, float theta) {
    float cosT = cos(theta);
    float sinT = sin(theta);

    struct CartesianCoordinate result;
    result.x = self->x * cosT + self->y * sinT;
    result.y = -self->x * sinT + self->y * cosT;
    result.z = self->z;
    return result;
}
struct CartesianCoordinate ImageCoordinate_normalize(struct ImageCoordinate* self, float rho) {
    struct CartesianCoordinate result;
    result.x = ((float)self->x*2)/self->w - 1;
    result.z = ((float)self->y*2)/self->h - 1;
    CartesianCoordinate_fixY(&result, rho);
    return result;
}
struct SphericalCoordinate SphericalCoordinate_fromNormalized(struct CartesianCoordinate normalized) {
    struct SphericalCoordinate result;
    result.rho = 1;
    result.theta = (normalized.z + 1)/2 * M_PI;
    result.phi = (normalized.x + 1)/2 * M_PI * 2;
    return result;
}
