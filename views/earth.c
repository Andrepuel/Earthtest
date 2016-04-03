#ifndef __OPENCL_VERSION__
#define __kernel
#define __global
int get_global_id(int);
#include "coordinate.c"
#endif

struct Argb32* getLine(__global unsigned char* img, int y, int stride);

struct Argb32 {
    unsigned char b, g, r, a;
};

struct Argb32* getLine(__global unsigned char* img, int y, int stride) {
    return (struct Argb32*)(img + y * stride);
}

struct ImageMeta {
    int w, h, stride;
};

__kernel void createImage(__global unsigned char* inputRaw, __global unsigned char* outputRaw, struct ImageMeta inputMeta, struct ImageMeta outputMeta, int isGlobe, float rotX, float rotY, float rotZ) {
    struct ImageCoordinate xy;
    xy.x = get_global_id(0);
    xy.y = get_global_id(1);
    xy.w = outputMeta.w;
    xy.h = outputMeta.h;

    struct Argb32* outputLine = getLine(outputRaw, xy.y, outputMeta.stride);

    struct CartesianCoordinate xyNorm = ImageCoordinate_normalize(&xy, 1.0f);

    if (isGlobe == 1) {
        xyNorm.x = (xyNorm.x + 1)/2 * 2;
        int pos = xyNorm.x;
        xyNorm.x = (xyNorm.x - pos) * 2 - 1;
        CartesianCoordinate_fixY(&xyNorm, 1.0f);

        if (!isnan(xyNorm.y)) {
            if (pos == 1) {
                xyNorm = CartesianCoordinate_rotZ(&xyNorm, -M_PI);
            }
            xyNorm = CartesianCoordinate_rotZ(&xyNorm, -rotZ);
            xyNorm = CartesianCoordinate_rotY(&xyNorm, -rotY);
            xyNorm = CartesianCoordinate_rotX(&xyNorm, -rotX);

            struct SphericalCoordinate spherical = CartesianCoordinate_toSpherical(&xyNorm);
            struct CartesianCoordinate uv = SphericalCoordinate_normalize(&spherical);
            uv.x = -uv.x;
            uv.z = -uv.z;
            struct ImageCoordinate inputXy = CartesianCoordinate_toImage(&uv, inputMeta.w, inputMeta.h);
            struct Argb32* inputLine = getLine(inputRaw, inputXy.y, inputMeta.stride);
            outputLine[xy.x] = inputLine[inputXy.x];
        } else {
            outputLine[xy.x].a = 255;
            outputLine[xy.x].r = 0;
            outputLine[xy.x].g = 0;
            outputLine[xy.x].b = 0;
        }
    } else {
        struct SphericalCoordinate spherical = SphericalCoordinate_fromNormalized(xyNorm);
        xyNorm = SphericalCoordinate_toCartesian(&spherical);
        xyNorm = CartesianCoordinate_rotZ(&xyNorm, -rotZ);
        xyNorm = CartesianCoordinate_rotY(&xyNorm, -rotY);
        xyNorm = CartesianCoordinate_rotX(&xyNorm, -rotX);
        spherical = CartesianCoordinate_toSpherical(&xyNorm);
        struct CartesianCoordinate uv = SphericalCoordinate_normalize(&spherical);
        struct ImageCoordinate inputXy = CartesianCoordinate_toImage(&uv, inputMeta.w, inputMeta.h);
        struct Argb32* inputLine = getLine(inputRaw, inputXy.y, inputMeta.stride);
        outputLine[xy.x] = inputLine[inputXy.x];
    }
}
