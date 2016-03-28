import cairo.ImageSurface;

struct Argb32 {
    ubyte b;
    ubyte g;
    ubyte r;
    ubyte a;
};

struct Image {
    int w;
    int h;
    ubyte[] data;

    Argb32[] opIndex(size_t line) {
        ubyte[] offset = data[ImageSurface.formatStrideForWidth(cairo_format_t.ARGB32, w) * line ..$];
        return cast(Argb32[]) offset[0..w*Argb32.sizeof];
    }

    static Image allocate(int w, int h)
    {
        Image result;
        result.data = new ubyte[size_t.sizeof*2 + ImageSurface.formatStrideForWidth(cairo_format_t.ARGB32, w) * h];
        result.w = w;
        result.h = h;
        return result;
    }

    ImageSurface surface() {
        return ImageSurface.createForData(data.ptr, cairo_format_t.ARGB32, w, h, ImageSurface.formatStrideForWidth(cairo_format_t.ARGB32, w));
    }

    static Image fromSurface(ImageSurface surface)
    {
        Image result;
        result.h = surface.getHeight();
        result.w = surface.getWidth();
        result.data = surface.getData()[0..ImageSurface.formatStrideForWidth(cairo_format_t.ARGB32, surface.getWidth()) * surface.getHeight()];
        return result;
    }
};

class Earth {
    private:
        ImageSurface imageOrig;
        Image imageMeta;
        ImageSurface image;

    public:
        this(string origFile, int w, int h) {
            imageOrig = ImageSurface.createFromPng(origFile);
            imageMeta = Image.allocate(w, h);
            image = imageMeta.surface();
        }

        void createImage(double dRotZ, double dRotY, bool globe) {
            import std.math;
            import coordinate;
            import interpolate;

            auto imageOrigMeta = Image.fromSurface(imageOrig);

            foreach (y; 0..imageMeta.h) {
                auto line = imageMeta[y];
                CartesianCoordinate relative;
                relative.z = (cast(double) y*2)/imageMeta.h - 1;
                foreach (x; 0..imageMeta.w) {
                    line[x].a = 255;
                    relative.x = (cast(double) x*2)/imageMeta.w - 1;
                    if (globe) {
                        relative.fixY();
                        if (!relative.y.isNaN) {
                            auto spherical = relative.toSpherical();
                            spherical.phi -= dRotZ;
                            while (spherical.phi < 0) spherical.phi += PI*2;
                            spherical = spherical.rotX(dRotY);
                            auto renormalize = spherical.normalize();
                            renormalize.z *= -1;
                            renormalize.x *= -1;
                            auto origin = renormalize.toImage(imageOrigMeta.w, imageOrigMeta.h);
                            line[x] = imageOrigMeta[origin.y][origin.x];
                        } else {
                            line[x].r = 255;
                            line[x].g = 255;
                            line[x].b = 255;
                        }
                    } else {
                        auto renormalize = SphericalCoordinate.fromNormalized(relative).rotZ(dRotZ).rotX(dRotY).normalize;
                        auto origin = renormalize.toImage(imageOrigMeta.w, imageOrigMeta.h);
                        line[x] = imageOrigMeta[origin.y][origin.x];
                    }
                }
            }
            this.image.markDirty();
        }

        ImageSurface surface() {
            return image;
        }

};