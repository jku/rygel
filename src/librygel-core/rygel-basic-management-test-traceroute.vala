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

// Helper class for BasicManagementTestTraceroute.
internal class Rygel.BasicManagementTestTraceroute : BasicManagementTest {
    private static const uint MIN_TIMEOUT = 1000;
    private static const uint MAX_TIMEOUT = 30000;
    private static const uint DEFAULT_TIMEOUT = 5000;
    private static const uint MIN_DATA_BLOCK_SIZE = 20;
    private static const uint MAX_DATA_BLOCK_SIZE = 2048;
    private static const uint DEFAULT_DATA_BLOCK_SIZE = 32;
    private static const uint MAX_DSCP = 64;
    private static const uint DEFAULT_DSCP = 30;
    private static const uint MAX_HOPS = 64;
    private static const uint DEFAULT_HOPS = 30;
    private static const uint MAX_HOSTS = 2048;
    private static const uint MAX_RESULT_SIZE = 4;

    public string host { construct; get; default = ""; }

    private uint32 _wait_time_out;
    public uint32 wait_time_out {
        construct {
            this._wait_time_out = value;
            if (this._wait_time_out == 0)
                this._wait_time_out = DEFAULT_TIMEOUT;
        }
        get { return this._wait_time_out; }
        default = DEFAULT_TIMEOUT;
    }

    private uint _data_block_size;
    public uint data_block_size {
        construct {
            this._data_block_size = value;
            if (this._data_block_size == 0)
                this._data_block_size = DEFAULT_DATA_BLOCK_SIZE;
        }
        get { return this._data_block_size; }
        default = DEFAULT_DATA_BLOCK_SIZE;
    }

    private uint _max_hop_count;
    public uint max_hop_count {
        construct {
            this._max_hop_count = value;
            if (this._max_hop_count == 0)
                this._max_hop_count = DEFAULT_HOPS;
        }
        get { return this._max_hop_count; }
        default = DEFAULT_HOPS;
    }

    private uint _dscp;
    public uint dscp {
        construct {
            this._dscp = value;
            if (this._dscp == 0)
                this._dscp = DEFAULT_DSCP;
        }
        get { return this._dscp; }
        default = DEFAULT_DSCP;
    }

    private string status;
    private string additional_info;
    private uint32 response_time;
    private string hop_hosts;

    public override string method_type { get { return "Traceroute"; } }
    public override string results_type { get { return "GetTracerouteResult"; } }

    public BasicManagementTestTraceroute (string host,
                                          uint32 wait_time_out,
                                          uint data_block_size,
                                          uint max_hop_count,
                                          uint dscp) {
        Object (host: host,
                wait_time_out: wait_time_out,
                data_block_size: data_block_size,
                max_hop_count: max_hop_count,
                dscp: dscp);
    }

    public override void constructed () {
        base.constructed ();

        stdout.printf("*Traceroute* constructed()\n");

        /* Fail early if internal parameter limits are violated */
        if (this.wait_time_out < MIN_TIMEOUT ||
            this.wait_time_out > MAX_TIMEOUT) {

            this.init_state = InitState.INVALID_PARAMETER;
            var msg = "Timeout %u is not in allowed range [%u, %u]";
            this.additional_info = msg.printf (this.wait_time_out,
                                               MIN_TIMEOUT,
                                               MAX_TIMEOUT);

        } else if (this.data_block_size < MIN_DATA_BLOCK_SIZE ||
                   this.data_block_size > MAX_DATA_BLOCK_SIZE) {
            this.init_state = InitState.INVALID_PARAMETER;
            var msg = "DataBlockSize %u is not in allowed range [%u, %u]";
            this.additional_info = msg.printf (this.data_block_size,
                                               MIN_DATA_BLOCK_SIZE,
                                               MAX_DATA_BLOCK_SIZE);

        } else if (this.max_hop_count > MAX_HOPS) {
            this.init_state = InitState.INVALID_PARAMETER;
            var msg = "MaxHopCount %u is not in allowed range [0, %u]";
            this.additional_info = msg.printf (this.max_hop_count,
                                               MAX_HOPS);

        } else if (this.dscp > MAX_DSCP) {
            this.init_state = InitState.INVALID_PARAMETER;
            var msg = "DSCP %u is not in allowed range [0, %u]";
            this.additional_info = msg.printf (this.dscp, MAX_DSCP);
        }
    }

    public void get_results(out string status, out string additional_info,
                            out uint32 response_time, out string hop_hosts) {
        stdout.printf("*Traceroute* get_results()\n");

        status = this.status;
        additional_info = this.additional_info;
        response_time = this.response_time;
        hop_hosts = this.hop_hosts;
    }
}
