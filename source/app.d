/**
 * main.d
 *
 * A gtkD main window that uses the clock widget from clock.d
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

module main;

import image_display;

import gtk.MainWindow;
import gtk.Main;
import gtk.Widget;
import gdk.Event;

import earth;

void callThread(void delegate(int id) worker, int i) {
    import core.thread;

    int j = i;
    auto a = new Thread(() { worker(j); });
    a.isDaemon = true;
    a.start();
}

void redraw(Earth earth, double seconds, int worker, int numThreads) {
    import std.math;

    double rotZ = seconds * 2 * PI / 360;
    double rotX = seconds * 2 * PI / 10;
    earth.createImage(rotZ, 0, rotX, false, worker, numThreads);
}

void main(string[] args)
{
    if (1) {
        import std.stdio;
        import std.math : PI;

        Main.init(args);
        
        MainWindow win = new MainWindow("gtkD Cairo Clock");
        
        enum baseSize = 1400;
        // enum baseSize = 4000;
        win.setDefaultSize(baseSize, baseSize/2);

        int lastX = -1;
        int lastY = -1;
        int rotZ = 0;
        int rotY = 0;
        int rotX = 0;
        bool globe = false;

        Earth earth = new Earth("earth.png", baseSize, baseSize/2);

        auto draw = () { earth.createImage((cast(double)rotZ)/180 * PI, (cast(double)rotY)/180 * PI, (cast(double)rotX)/180 * PI, globe); };

        auto c = new ImageDisplay(earth.surface(), (secs) {});
        c.addOnButtonRelease(
            (GdkEventButton* event, Widget widget) {
                if ((event.state & GdkModifierType.BUTTON3_MASK) > 0 ) {
                    globe = !globe;
                }
                draw();
                return false;
            }
        );
        c.addOnScroll(
            (GdkEventScroll* event, Widget widget) {
                int deltaY = cast(int) (event.deltaY * 6);
                if (event.direction == GdkScrollDirection.UP) deltaY *= -1;
                rotY += deltaY;
                draw();
                return false;
            }
        );
        c.addOnMotionNotify(
            (GdkEventMotion* event, Widget widget) {
                if (lastX >= 0 && (event.state & GdkModifierType.BUTTON1_MASK) > 0) {
                    int dx = (cast(int) event.x) - lastX;
                    int dy = (cast(int) event.y) - lastY;
                    rotZ += dx;
                    rotX += dy;
                    while (rotZ < 0) rotZ += 360;
                    rotZ = rotZ % 360;
                    while (rotX < 0) rotX += 360;
                    rotX = rotX % 360;
                    draw();
                }
                lastX = cast(int) event.x;
                lastY = cast(int) event.y;

                return false;
            }
        );
        draw();
        c.addEvents(EventMask.BUTTON_PRESS_MASK);
        win.add(c);
        c.show();
        win.showAll();

        Main.run();
    } else {
        import std.math;
        import std.format;
        import std.stdio;
        import core.sync.barrier;
        import std.process;
        import std.format;

        enum fps = 24;
        enum duration = 360;
        enum output = "out/project_%05d.png";

        int numThreads = 5;
        auto barrier = new Barrier(numThreads);
        Earth earth = new Earth("earth.png", 1920, 1920/2);
        auto worker = (int worker) {
            foreach(i; 0..duration*fps) {
                double seconds = (cast(double)i)/fps;
                redraw(earth, seconds, worker, numThreads);
                barrier.wait();
                barrier.wait(); 
            }
        };

        foreach(i; 1..numThreads) {
            callThread(worker, i);
        }

        auto pipe = pipe();
        auto ffmpeg = spawnProcess(["/usr/bin/env", "ffmpeg", "-f", "rawvideo", "-pixel_format", "rgb24", "-video_size", "%sx%s".format(1920, 1920/2), "-framerate", "%s".format(fps), "-i", "-", "output.mp4"], pipe.readEnd);
        scope(exit) wait(ffmpeg);

        foreach(i; 0..duration*fps) {
            double seconds = (cast(double)i)/fps;
            redraw(earth, seconds, 0, numThreads);
            barrier.wait();
            File write = pipe.writeEnd;
            Image.fromSurface(earth.surface).rawWrite(write);
            barrier.wait();
        }

        pipe.writeEnd.close();
    }
}
