/*
 * Copyright (C) 2013 Intel Corporation.
 *
 * Author: Christophe Guiraud,
 *         Jussi Kukkonen 
 *
 * This file is part of Rygel.
 *
 * Rygel is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Rygel is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

using GLib;


internal errordomain Rygel.BMTestError {
    NOT_POSSIBLE,
    INIT_FAILED,
}

internal abstract class Rygel.BMTest : Object {
    public string type;
    public string state;
    public string id;

    public bool executing { private set; get; default = false; }

    /* properties for implementations to access */
    protected SpawnFlags flags = SpawnFlags.SEARCH_PATH |
                                 SpawnFlags.LEAVE_DESCRIPTORS_OPEN;
    protected string[] command;
    protected uint execution_time { private set; get; default = 0; } 
    protected uint repetitions;

    private int std_out;
    private int std_err;
    private Pid child_pid;
    private SourceFunc async_callback;
    private bool canceled;
    private uint iteration;

    /* These virtual/abstract functions will be called from execute():
     * - For every iteration:
     *    - init_iteration()
     *    - calls to handle_output() and handle_error(),
     *    - finish_iteration()
     * - then finish() 
     */
    protected virtual void init_iteration () {}
    protected virtual void handle_output (string line) {}
    protected virtual void handle_error (string line) {
        warning ("%s stderr: %s", command[0], line);
    }
    protected virtual void finish_iteration () {
        iteration++;
        if (iteration < repetitions) {
            run_iteration ();
        } else {
            async_callback ();
        }
    }
    protected virtual void finish (bool canceled) {}

        
    private void child_setup () {
        /* try to prevent possible changes in output */
        Environment.set_variable("LC_MESSAGES", "C", true);

        /* Create new session to detach from tty, but set a process
         * group so all children can be ḱilled if need be */
        Posix.setsid ();
        Posix.setpgid (0, 0);
    }

    private void run_iteration () {
        try {
            init_iteration ();
            Process.spawn_async_with_pipes (null,
                                            command,
                                            null,
                                            flags,
                                            child_setup,
                                            out child_pid,
                                            null,
                                            out std_out,
                                            out std_err);

            var out_channel = new IOChannel.unix_new (std_out);
            out_channel.add_watch (IOCondition.OUT | IOCondition.HUP,
                                   out_watch);

            var err_channel = new IOChannel.unix_new (std_err);
            err_channel.add_watch (IOCondition.OUT | IOCondition.HUP,
                                   err_watch);
        } catch (SpawnError e) {
            /* TODO cancel all iterations and let the implementation know
             * we failed to spawn */
        }
    }

    private bool out_watch (IOChannel channel, IOCondition condition) {
        try {
            string line;
            IOStatus status = channel.read_line (out line, null, null);
            if (line != null)
                handle_output (line);

            if (status == IOStatus.EOF) {
                finish_iteration ();
                return false;
            }
        } catch (Error e) {
            warning ("Failed readline() from nslookup stdout: %s", e.message);
            finish_iteration();
            return false;
        }

        return true;
    }

    private bool err_watch (IOChannel channel, IOCondition condition) {
        try {
            string line;
            IOStatus status = channel.read_line (out line, null, null);
            if (line != null)
                handle_error (line);
            if (status == IOStatus.EOF)
                return false;
        } catch (Error e) {
            warning ("Failed readline() from nslookup stderr: %s", e.message);
            return false;
        }

        return true;
    }


    public BMTest(string type) {
        this.type = type;
        this.state = "Requested";
        this.id = null;
    }

    public async void execute () throws BMTestError {
        if (executing)
            throw new BMTestError.NOT_POSSIBLE ("Already executing");

        executing = true;
        canceled = false;
        iteration = 0;

        run_iteration ();

        async_callback = execute.callback;
        yield;

        executing = false;
        finish (canceled);
        return ;
    }

    public void cancel () throws BMTestError {
        if (!executing)
            throw new BMTestError.NOT_POSSIBLE ("Not executing"); 

        Posix.killpg (child_pid, Posix.SIGTERM);

        canceled = true;
    }
}
