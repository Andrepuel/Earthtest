/**
 * clock.d
 *
 * A gtkD widget that implements a clock face
 *
 * Based on the Gtkmm example by:
 * Jonathon Jongsma
 *
 * and the original GTK+ example by:
 * (c) 2005-2006, Davyd Madeley
 *
 * Authors:
 *   Jonas Kivi (D version)
 *   Jonathon Jongsma (C++ version)
 *   Davyd Madeley (C version)
 */

module clock;

import std.stdio;
import std.math;
import std.datetime;

import glib.Timeout;

import cairo.Context;
import cairo.Surface;
import cairo.ImageSurface;

import gtk.Widget;
import gtk.DrawingArea;

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

class Clock : DrawingArea
{
public:
    void createImage() {
        debug import std.stdio;
        import std.datetime;
        import std.math;
        import coordinate;
        import interpolate;

        auto imageOrigMeta = Image.fromSurface(imageOrig);
        auto total = (Clock.currTime() - SysTime(DateTime(2000, 1, 1), null)).total!"msecs";
        double dPhi = (total%12000)*2*PI/12000.0;
        double dRotY = (total%7600)*2*PI/7600.0;

        enum USE_UV = false;

        if (USE_UV) {
            enum UV_W = 64;
            enum UV_H = 64;

            double[UV_W*UV_H][2] uv_data;
            Grid[2] uv;
            uv[0].w = UV_W;
            uv[0].h = UV_H;
            uv[0].data = uv_data[0][];
            uv[1].w = UV_W;
            uv[1].h = UV_H;
            uv[1].data = uv_data[1][];

            foreach (v; 0..UV_H) {
                foreach(u; 0..UV_W) {
                    auto relative = ImageCoordinate(u, v, UV_W, UV_H).normalize();
                    if (relative.y.isNaN) relative.y = 0;

                    auto spherical = relative.toSpherical();
                    spherical.phi -= dPhi;
                    while (spherical.phi < 0) spherical.phi += PI*2;
                    auto renormalize = spherical.normalize();
                    renormalize.x = -renormalize.x;
                    renormalize.z = -renormalize.z;
                    uv[0][v][u] = renormalize.x;
                    uv[1][v][u] = renormalize.z;
                }
            }

            foreach (y; 0..imageMeta.h) {
                auto line = imageMeta[y];
                foreach (x; 0..imageMeta.w) {
                    line[x].a = 255;
                    auto relative = ImageCoordinate(x, y, imageMeta.w, imageMeta.h).normalize();
                    CartesianCoordinate renormalize;
                    renormalize.x = interpolate.interpolate(relative.x, relative.z, uv[0]);
                    renormalize.z = interpolate.interpolate(relative.x, relative.z, uv[1]);
                    auto origin = renormalize.toImage(imageOrigMeta.w, imageOrigMeta.h);
                    line[x] = imageOrigMeta[origin.y][origin.x];
                }
            }

        } else {
            foreach (y; 0..imageMeta.h) {
                auto line = imageMeta[y];
                CartesianCoordinate relative;
                relative.z = (cast(double) y*2)/imageMeta.h - 1;
                foreach (x; 0..imageMeta.w) {
                    line[x].a = 255;
                    relative.x = (cast(double) x*2)/imageMeta.w - 1;
                    relative.fixY();
                    if (!relative.y.isNaN) {
                        auto spherical = relative.toSpherical();
                        spherical.phi -= dPhi;
                        if (spherical.phi < 0) spherical.phi += PI*2;
                        spherical = spherical.rotY(dRotY);
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
                }
            }
        }
        this.image.markDirty();
    }

	this()
	{
        import std.stdio;
        import std.math;

        imageOrig = ImageSurface.createFromPng("earth.png");
        imageMeta = Image.allocate(200, 200);
        this.image = imageMeta.surface();
        createImage();

        imageW = imageMeta.w;
        imageH = imageMeta.h;
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);
	}

protected:
    bool drawCallback(Scoped!Context cr, Widget widget)
    {
        createImage();

		if ( m_timeout is null )
		{
			//Create a new timeout that will ask the window to be drawn once every second.
			m_timeout = new Timeout( 1000/30, &onSecondElapsed, false );
		}

		GtkAllocation size;

		getAllocation(size);

		// scale to unit square and translate (0, 0) to be (0.5, 0.5), i.e. the
		// center of the window
		cr.scale(size.width/2.0, size.height/2.0);
	    cr.translate(1, 1);
        cr.setLineWidth(0.01);

        if (0) {
            cr.save(); scope(exit) cr.restore();
            cr.moveTo(0.0, 0.0);
            cr.lineTo(0.5, 0.5);
			cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
            cr.strokePreserve();
        }

        if (0) {
            cr.save(); scope(exit) cr.restore();
            cr.scale(256/imageW, 256/imageH);
            cr.setSourceSurface(image, 0.0, 0.0);
            cr.translate(-0.5*imageW, -0.5*imageH);
            cr.paint();
        }

        {
            //cr.arc (0.0, 0.0, 0.9, 0, 2*3.1415926536);
            //cr.clip ();
            //cr.newPath (); /* path not consumed by clip()*/

            int w = imageW;
            int h = imageH;

            cr.translate(-1., -1.);
            cr.scale (2.0/w, 2.0/h);
            cr.setSourceSurface (image, 0, 0);
            //cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
            cr.paint();
        }

        return true;
    }

	bool onSecondElapsed()
	{
		//force our program to redraw the entire clock once per every second.
		GtkAllocation area;
		getAllocation(area);

		queueDrawArea(area.x, area.y, area.width, area.height);
		
		return true;
	}

	double m_radius = 0.40;
	double m_lineWidth = 0.065;

	Timeout m_timeout;
    Surface image;
    Image imageMeta;
    ImageSurface imageOrig;
    int imageW;
    int imageH;
}
