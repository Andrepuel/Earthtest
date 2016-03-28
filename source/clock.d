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

import earth;

class Clock : DrawingArea
{
public:

	this()
	{
        import std.stdio;
        import std.math;

        earth = new Earth("earth.png", 200, 200);
        createImage();
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);
	}

    void createImage() {
        import std.datetime;

        auto total = (Clock.currTime() - SysTime(DateTime(2000, 1, 1), null)).total!"msecs";
        double dPhi = (total%360000)*2*PI/36000.0;
        double dRotY = (total%10000)*2*PI/10000.0;

        enum GLOBE = false;
        earth.createImage(dPhi, dRotY, true);
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

            int w = earth.surface.getWidth();
            int h = earth.surface.getHeight();

            cr.translate(-1., -1.);
            cr.scale (2.0/w, 2.0/h);
            cr.setSourceSurface (earth.surface, 0, 0);
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
    Earth earth;
}
