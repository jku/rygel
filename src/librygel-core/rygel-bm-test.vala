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
    public enum ExecutionState {
        REQUESTED,
        IN_PROGRESS,
        COMPLETED,
        SPAWN_FAILED,
        CANCELED;

        /* Return values fit for A_ARG_TYPE_TestState */
        public string to_string () { 
            switch (this) {
                case REQUESTED:
                    return "Requested";
                case IN_PROGRESS:
                    return "InProgress";
                case COMPLETED:
                    return "Completed";
                case SPAWN_FAILED:
                    return "Completed";
                case CANCELED:
                    return "Canceled";
                default:
                    assert_not_reached ();
            }
        }
    }
    public ExecutionState execution_state;
    public string id;

    /* properties implementations need to provide */
    public abstract string method_type { get; }
    public abstract string results_type { get; }

    /* properties for implementations to access */
    protected SpawnFlags flags = SpawnFlags.SEARCH_PATH |
                                 SpawnFlags.LEAVE_DESCRIPTORS_OPEN;
    protected string[] command;
    protected uint repetitions;

    private int std_out;
    private int std_err;
    private Pid child_pid;
    private SourceFunc async_callback;
    private uint iteration;

    /* These virtual/abstract functions will be called from execute():
     * - For every iteration:
     *    - init_iteration()
     *    - calls to handle_output() and handle_error(),
     *    - finish_iteration()
     */
    protected virtual void init_iteration () {}
    protected virtual void handle_output (string line) {}
    protected virtual void handle_error (string line) {
        warning ("%s stderr: %s", command[0], line);
    }
    protected virtual void finish_iteration () {
        iteration++;
        if (execution_state != ExecutionState.IN_PROGRESS) {
            async_callback ();
        } else if (iteration >= repetitions) {
            execution_state = ExecutionState.COMPLETED;
            async_callback ();
        } else {
            run_iteration ();
        }
    }
        
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
            /* Let the async function yeild, then error out */
            execution_state = ExecutionState.SPAWN_FAILED;
            Idle.add ((SourceFunc)finish_iteration);
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
            /* TODO set execution_state ? */
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


    public BMTest() {
        this.execution_state = ExecutionState.REQUESTED;
        this.id = null;
    }

    public async virtual void execute () throws BMTestError {
        if (execution_state != ExecutionState.REQUESTED)
            throw new BMTestError.NOT_POSSIBLE ("Already executing or executed");

        execution_state = ExecutionState.IN_PROGRESS;
        iteration = 0;
        async_callback = execute.callback;

        run_iteration ();
        yield;

        return;
    }

    public void cancel () throws BMTestError {
        if (execution_state != ExecutionState.IN_PROGRESS)
            throw new BMTestError.NOT_POSSIBLE ("Not executing"); 

        Posix.killpg (child_pid, Posix.SIGTERM);

        execution_state = ExecutionState.CANCELED;
    }
}
