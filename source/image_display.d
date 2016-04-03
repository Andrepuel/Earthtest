module image_display;

import std.stdio;
import std.math;
import std.datetime;

import glib.Timeout;

import cairo.Context;
import cairo.Surface;
import cairo.ImageSurface;

import gtk.Widget;
import gtk.DrawingArea;
import std.datetime;

class ImageDisplay : DrawingArea
{
public:

	this(ImageSurface surface, void delegate(double elapsedSeconds) redraw)
	{
        start = Clock.currTime();
        this.redraw = redraw;
        this.surface = surface;
        redraw(0);

		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);
	}

    void createImage() {
        auto total = (Clock.currTime() - start).total!"msecs";
        this.redraw(total/1000.0);
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

        {

            int w = surface.getWidth();
            int h = surface.getHeight();

            cr.translate(-1., -1.);
            cr.scale (2.0/w, 2.0/h);
            cr.setSourceSurface(surface, 0, 0);
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

	Timeout m_timeout;
    ImageSurface surface;
    SysTime start;
    void delegate(double) redraw;
}
