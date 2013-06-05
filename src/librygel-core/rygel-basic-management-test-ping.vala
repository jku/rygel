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

// Helper class for BasicManagementTestPing.
internal class Rygel.BasicManagementTestPing : BasicManagementTest {
    private enum ProcessState {
        INIT,
        STATISTICS,
        RTT,
    }

    private enum Status {
        SUCCESS,
        ERROR_CANNOT_RESOLVE_HOSTNAME,
        ERROR_INTERNAL,
        ERROR_OTHER;

        public string to_string() {
            switch (this) {
                case SUCCESS:
                    return "Success";
                case ERROR_CANNOT_RESOLVE_HOSTNAME:
                    return "Error_CannotResolveHostName";
                case ERROR_INTERNAL:
                    return "Error_Internal";
                case ERROR_OTHER:
                    return "Error_Other";
                default:
                    assert_not_reached();
            }
        }
    }

    private ProcessState state;
    private Status status;
    private string additional_info;
    private uint success_count;
    private uint failure_count;
    private uint32 avg_response_time;
    private uint32 min_response_time;
    private uint32 max_response_time;

    private static const uint MIN_REPEAT_COUNT = 1;
    private static const uint MAX_REPEAT_COUNT = 100;
    private static const uint DEFAULT_REPEAT_COUNT = 1;
    private static const uint DEFAULT_REPLY_TIMEOUT = 10000;
    private static const uint MIN_REQUEST_INTERVAL_TIMEOUT = 1000;
    private static const uint MAX_REQUEST_INTERVAL_TIMEOUT = 30000;
    private static const uint DEFAULT_REQUEST_INTERVAL_TIMEOUT = 10000;
    private static const uint MIN_DATA_BLOCK_SIZE = 20;
    private static const uint MAX_DATA_BLOCK_SIZE = 2048;
    private static const uint DEFAULT_DATA_BLOCK_SIZE = 32;
    private static const uint MIN_DSCP = 1;
    private static const uint MAX_DSCP = 64;
    private static const uint DEFAULT_DSCP = 30;

    public override string method_type { get { return "Ping"; } }
    public override string results_type { get { return "GetPingResult"; } }

    public void init(string host, uint repeat_count, uint data_block_size,
                     uint dscp, uint32 interval_time_out)
                     throws BasicManagementTestError {
        this.command = { "ping" };
        this.status = Status.ERROR_INTERNAL;
        this.additional_info = "";
        this.success_count = 0;
        this.failure_count = 0;
        this.avg_response_time = 0;
        this.min_response_time = 0;
        this.max_response_time = 0;

        if (repeat_count == 0) {
            repeat_count = DEFAULT_REPEAT_COUNT;
        } else if (repeat_count < MIN_REPEAT_COUNT &&
                   repeat_count > MAX_REPEAT_COUNT) {
            throw new BasicManagementTestError.INIT_FAILED
                                                ("Invalid repeat count");
        }
        this.command += ("-c %u").printf (repeat_count);

        this.command += ("-W %u").printf (DEFAULT_REPLY_TIMEOUT/1000);

        if (interval_time_out == 0) {
            interval_time_out = DEFAULT_REQUEST_INTERVAL_TIMEOUT;
        } else if (interval_time_out < MIN_REQUEST_INTERVAL_TIMEOUT &&
                   interval_time_out > MAX_REQUEST_INTERVAL_TIMEOUT) {
            throw new BasicManagementTestError.INIT_FAILED
                                                ("Invalid interval timeout");
        }
        this.command += ("-i %u").printf (interval_time_out/1000);

        if (data_block_size == 0) {
            data_block_size = DEFAULT_DATA_BLOCK_SIZE;
        } else if (data_block_size < MIN_DATA_BLOCK_SIZE &&
                   data_block_size > MAX_DATA_BLOCK_SIZE) {
            throw new BasicManagementTestError.INIT_FAILED
                                                ("Invalid data block size");
        }
        this.command += ("-s %u").printf (data_block_size);

        if (dscp == 0) {
            dscp = DEFAULT_DSCP;
        } else if (dscp < MIN_DSCP && dscp > MAX_DSCP) {
            throw new BasicManagementTestError.INIT_FAILED
                                                ("Invalid DSCP");
        }
        this.command += ("-Q %u").printf (dscp >> 2);

        if (host == null || host.length < 1) {
            throw new BasicManagementTestError.INIT_FAILED
                                                ("Host name is required");
        }

        this.command += host;
    }

    protected override void init_iteration () {
        base.init_iteration ();

        this.state = ProcessState.INIT;
    }

    protected override void finish_iteration () {
        switch (this.execution_state) {
            case ExecutionState.SPAWN_FAILED:
                this.status = Status.ERROR_INTERNAL;
                this.additional_info = "Failed spawn ping";
                break;
            default:
                break;
        }

        base.finish_iteration ();
    }

    protected override void handle_error (string line) {
        if (line.contains ("ping: unknown host")) {
            this.status = Status.ERROR_CANNOT_RESOLVE_HOSTNAME;
            this.execution_state = ExecutionState.COMPLETED;
        } else if (line.contains ("ping:")) {
            this.status = Status.ERROR_OTHER;
            this.additional_info = line.substring ("ping:".length).strip ();
            this.execution_state = ExecutionState.COMPLETED;
        }
    }

    protected override void handle_output (string line) {
        line.strip ();
        if (this.state == ProcessState.INIT) {
            if (line.contains ("statistics ---")) {
                this.state = ProcessState.STATISTICS;
                this.status = Status.SUCCESS;
            }
        } else if (this.state == ProcessState.STATISTICS) {
            if (line.contains ("packets transmitted")) {
                this.state = ProcessState.RTT;

                var rtt_values = line.split (", ", 3);
                uint tx = int.parse (rtt_values[0].split (" ", 3)[0]);
                uint rx = int.parse (rtt_values[1].split (" ", 3)[0]);
                this.failure_count = tx - rx;
                this.success_count = rx;
            }
        } else if (this.state == ProcessState.RTT) {
            if (line.contains ("min/avg/max")) {
                this.execution_state = ExecutionState.COMPLETED;

                var rtt = line.split ("=", 2);
                if (rtt.length >= 2) {
                    var rtt_values = rtt[1].split ("/", 4);
                    if (rtt_values.length >= 3) {
                        this.avg_response_time = (uint) Math.round (
                                                  double.parse (rtt_values[0]));
                        this.min_response_time = (uint) Math.round (
                                                  double.parse (rtt_values[1]));
                        this.max_response_time = (uint) Math.round (
                                                  double.parse (rtt_values[2]));
                    }
                }
            }
        }
    }

    public void get_results(out string status, out string additional_info,
                            out uint success_count, out uint failure_count,
                            out uint32 avg_response_time,
                            out uint32 min_response_time,
                            out uint32 max_response_time) {
        status = this.status.to_string ();
        additional_info = this.additional_info;
        success_count = this.success_count;
        failure_count = this.failure_count;
        avg_response_time = this.avg_response_time;
        min_response_time = this.min_response_time;
        max_response_time = this.max_response_time;
    }
}
