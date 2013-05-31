/*
 * Copyright (C) 2008 OpenedHand Ltd.
 * Copyright (C) 2008 Zeeshan Ali <zeenix@gmail.com>.
 * Copyright (C) 2013 Intel Corporation.
 *
 * Author: Jorn Baayen <jorn@openedhand.com>
 *         Zeeshan Ali <zeenix@gmail.com>
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

// Helper class for BMTestTraceroute.
internal class Rygel.BMTestTraceroute : BMTest {

    private string host;
    private uint32 wait_time_out;
    private uint data_block_size;
    private uint max_hop_count;
    private uint dscp;

    private string status;
    private string additional_info;
    private uint32 response_time;
    private string hop_hosts;

    private static const uint TRACEROUTE_MIN_REQUEST_TIMEOUT = 1000;
    private static const uint TRACEROUTE_MAX_REQUEST_TIMEOUT = 30000;
    private static const uint TRACEROUTE_DEFAULT_REQUEST_TIMEOUT = 5000;
    private static const uint TRACEROUTE_MIN_DATA_BLOCK_SIZE = 20;
    private static const uint TRACEROUTE_MAX_DATA_BLOCK_SIZE = 2048;
    private static const uint TRACEROUTE_DEFAULT_DATA_BLOCK_SIZE = 32;
    private static const uint TRACEROUTE_MIN_DSCP = 1;
    private static const uint TRACEROUTE_MAX_DSCP = 64;
    private static const uint TRACEROUTE_DEFAULT_DSCP = 30;
    private static const uint TRACEROUTE_MIN_HOPS = 1;
    private static const uint TRACEROUTE_MAX_HOPS = 64;
    private static const uint TRACEROUTE_DEFAULT_HOPS = 30;
    private static const uint TRACEROUTE_MAX_HOSTS = 2048;
    private static const uint TRACEROUTE_MAX_RESULT_SIZE = 4;

    public override string method_type { get { return "Traceroute"; } }
    public override string results_type { get { return "GetTracerouteResult"; } }

    public bool init(string host, uint32 wait_time_out, uint data_block_size,
                     uint max_hop_count, uint dscp) {
        stdout.printf("*Traceroute* init()\n");

        if (host == null || host == "") {
            return false;
        }

        if (wait_time_out == 0) {
            wait_time_out = TRACEROUTE_DEFAULT_REQUEST_TIMEOUT;
        } else if (wait_time_out < TRACEROUTE_MIN_REQUEST_TIMEOUT &&
                   wait_time_out > TRACEROUTE_MAX_REQUEST_TIMEOUT) {
            return false;
        }

        if (data_block_size == 0) {
            data_block_size = TRACEROUTE_DEFAULT_DATA_BLOCK_SIZE;
        } else if (data_block_size < TRACEROUTE_MIN_DATA_BLOCK_SIZE &&
                   data_block_size > TRACEROUTE_MAX_DATA_BLOCK_SIZE) {
            return false;
        }

        if (max_hop_count == 0) {
            max_hop_count = TRACEROUTE_DEFAULT_HOPS;
        } else if (max_hop_count < TRACEROUTE_MIN_HOPS &&
                 max_hop_count > TRACEROUTE_MAX_HOPS) {
            return false;
        }

        if (dscp == 0) {
            dscp = TRACEROUTE_DEFAULT_DSCP;
        } else if (dscp < TRACEROUTE_MIN_DSCP && dscp > TRACEROUTE_MAX_DSCP) {
            return false;
        }

        this.host = host;
        this.wait_time_out = wait_time_out;
        this.data_block_size = data_block_size;
        this.max_hop_count = max_hop_count;
        this.dscp = dscp;

        return true;
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
