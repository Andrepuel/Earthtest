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
    earth.createImage(rotZ, rotX, true, worker, numThreads);
}

void main(string[] args)
{
    if (1) {
        Main.init(args);
        
        MainWindow win = new MainWindow("gtkD Cairo Clock");
        
        win.setDefaultSize(1400, 700);

        Earth earth = new Earth("earth.png", 200, 200/2);
        auto c = new ImageDisplay(earth.surface(), (secs) { redraw(earth, secs, 0, 1); });
        win.add(c);
        c.show();
        win.showAll();

        Main.run();
    } else {
        import std.math;
        import std.format;
        import std.stdio;
        import core.sync.barrier;

        enum fps = 24;
        enum duration = 360;
        enum output = "out/project_%05d.png";

        int numThreads = 5;
        auto barrier = new Barrier(numThreads + 1);
        Earth earth = new Earth("earth.png", 1920, 1920/2);
        auto worker = (int worker) {
            foreach(i; 0..duration*fps) {
                double seconds = (cast(double)i)/fps;
                redraw(earth, seconds, worker, numThreads);
                barrier.wait();
                barrier.wait(); 
            }
        };

        foreach(i; 0..numThreads) {
            callThread(worker, i);
        }

        foreach(i; 0..duration*fps) {
            barrier.wait();
            Image.fromSurface(earth.surface).rawWrite(stdout);
            barrier.wait();
        }
    }
}
