import cairo.ImageSurface;
import std.stdio : File;
import cltypes;

struct Rgb24 {
    ubyte r;
    ubyte g;
    ubyte b;
}

struct Argb32 {
    ubyte b;
    ubyte g;
    ubyte r;
    ubyte a;

    Rgb24 rgb() const pure {
        return Rgb24(r, g, b);
    }
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

    int stride() const {
        return stride(w);
    }

    static stride(int w) {
        return ImageSurface.formatStrideForWidth(cairo_format_t.ARGB32, w);
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

    void rawWrite(ref File output) {
        Rgb24[] buf;
        buf.length = w;
        foreach(y; 0..h) {
            auto line = this[y];
            foreach(x; 0..w) {
                buf[x] = line[x].rgb();
            }
            output.rawWrite(buf);
        }
    }
};

struct ImageMetaCl {
    int w, h, stride;
}

class Earth {
    private:
        ImageSurface imageOrig;
        Image imageMeta;
        ImageSurface image;

        Context context;
        Program program;
        CommandQueue queue;
        Mem input;
        Mem output;

    public:
        this(string origFile, int w, int h) {
            imageOrig = ImageSurface.createFromPng(origFile);
            imageMeta = Image.allocate(w, h);
            image = imageMeta.surface();

            import derelict.opencl.cl;
            static import coordinate;
            cl_device_id device = Context.selectFirstDevice(CL_DEVICE_TYPE_GPU);
            if (device is null) device = Context.selectFirstDevice(CL_DEVICE_TYPE_ALL);
            context = Context(device);
            program = Program(context, device, coordinate.clside ~ import("earth.c"));
            queue = CommandQueue(context, device);

            size_t inputSize = imageOrig.getHeight() * Image.stride(imageOrig.getWidth());
            input = Mem(context, CL_MEM_READ_ONLY, inputSize);
            output = Mem(context, CL_MEM_WRITE_ONLY,  h * Image.stride(w));
            queue.enqueueWriteBuffer(input, 0, inputSize, imageOrig.getData());
        }

        void createImage(double dRotZ, double dRotY, double dRotX, bool globe, int step = 0, int stepN = 1) {
            static if (1) {
                if (step != 0) return;
                Kernel kernel = Kernel(program, "createImage");
                kernel.setArg(0, input.buffer);
                kernel.setArg(1, output.buffer);
                kernel.setArg(2, ImageMetaCl(imageOrig.getWidth, imageOrig.getHeight, Image.stride(imageOrig.getWidth)));
                kernel.setArg(3, ImageMetaCl(imageMeta.w, imageMeta.h, imageMeta.stride));
                kernel.setArg!int(4, globe);
                kernel.setArg!float(5, dRotX);
                kernel.setArg!float(6, dRotY);
                kernel.setArg!float(7, dRotZ);
                queue.enqueueNDRange(kernel, [imageMeta.w, imageMeta.h], null);
                size_t outputSize = imageMeta.h * imageMeta.stride;
                queue.enqueueReadBuffer(output, 0, outputSize, imageMeta.data.ptr);
                queue.finish();
            } else {
                import std.math;
                import coordinate;
                import interpolate;

                auto imageOrigMeta = Image.fromSurface(imageOrig);

                int y0 = (step * imageMeta.h)/stepN;
                int y1 = ((step + 1) * imageMeta.h)/stepN;

                foreach (y; y0..y1) {
                    auto line = imageMeta[y];
                    CartesianCoordinate relative;
                    relative.z = (cast(double) y*2)/imageMeta.h - 1;
                    foreach (x; 0..imageMeta.w) {
                        line[x].a = 255;
                        relative.x = (cast(double) x*2)/imageMeta.w - 1;
                        if (globe) {
                            bool second = relative.x > 0;
                            if (second) {
                                relative.x -= 0.5;
                            } else {
                                relative.x += 0.5;
                            }
                            relative.x *= 2;
                            relative.fixY();
                            if (!relative.y.isNaN) {
                                auto spherical = relative.toSpherical();
                                if (second) spherical.phi += PI;
                                spherical.phi -= dRotZ;
                                while (spherical.phi < 0) spherical.phi += PI*2;
                                spherical = spherical.rotX(dRotX);
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
                            auto renormalize = SphericalCoordinate.fromNormalized(relative).rotZ(dRotZ).rotX(dRotX).normalize;
                            auto origin = renormalize.toImage(imageOrigMeta.w, imageOrigMeta.h);
                            line[x] = imageOrigMeta[origin.y][origin.x];
                        }
                    }
                }
            }
            this.image.markDirty();
        }

        ImageSurface surface() {
            return image;
        }

};
