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

// Helper class for BMTestPing.
internal class Rygel.BMTestPing : BMTest {

    private string host;
    private uint repeat_count;
    private uint data_block_size;
    private uint dscp;
    private uint32 interval_time_out;

    private string status;
    private string additional_info;
    private uint success_count;
    private uint failure_count;
    private uint32 average_response_time;
    private uint32 min_response_time;
    private uint32 max_response_time;

    private static const uint PING_MIN_REPEAT_COUNT = 1;
    private static const uint PING_MAX_REPEAT_COUNT = 100;
    private static const uint PING_DEFAULT_REPEAT_COUNT = 1;
    private static const uint PING_MIN_REQUEST_INTERVAL_TIMEOUT = 1000;
    private static const uint PING_MAX_REQUEST_INTERVAL_TIMEOUT = 30000;
    private static const uint PING_DEFAULT_REQUEST_INTERVAL_TIMEOUT = 10000;
    private static const uint PING_MIN_DATA_BLOCK_SIZE = 20;
    private static const uint PING_MAX_DATA_BLOCK_SIZE = 2048;
    private static const uint PING_DEFAULT_DATA_BLOCK_SIZE = 32;
    private static const uint PING_MIN_DSCP = 1;
    private static const uint PING_MAX_DSCP = 64;
    private static const uint PING_DEFAULT_DSCP = 30;
    private static const uint PING_MAX_ADDITIONAL_INFO_STR_SIZE = 1024;
    private static const uint PING_MAX_STATUS_STR_SIZE = 32;
    private static const uint PING_MAX_RESULT_ARRAY_SIZE = 7;

    public override string method_type { get { return "Ping"; } }
    public override string results_type { get { return "GetPingResult"; } }

    public bool init(string host, uint repeat_count, uint data_block_size,
                     uint dscp, uint32 interval_time_out) {
        stdout.printf("*Ping* init()\n");

        if (host == null || host == "") {
            return false;
        }

        if (repeat_count == 0) {
            repeat_count = PING_DEFAULT_REPEAT_COUNT;
        } else if (repeat_count < PING_MIN_REPEAT_COUNT &&
                   repeat_count > PING_MAX_REPEAT_COUNT) {
            return false;
        }

        if (interval_time_out == 0) {
            interval_time_out = PING_DEFAULT_REQUEST_INTERVAL_TIMEOUT;
        } else if (interval_time_out < PING_MIN_REQUEST_INTERVAL_TIMEOUT &&
                   interval_time_out > PING_MAX_REQUEST_INTERVAL_TIMEOUT) {
            return false;
        }

        if (data_block_size == 0) {
            data_block_size = PING_DEFAULT_DATA_BLOCK_SIZE;
        } else if (data_block_size < PING_MIN_DATA_BLOCK_SIZE &&
                   data_block_size > PING_MAX_DATA_BLOCK_SIZE) {
            return false;
        }

        if (dscp == 0) {
            dscp = PING_DEFAULT_DSCP;
        } else if (dscp < PING_MIN_DSCP && dscp > PING_MAX_DSCP) {
            return false;
        }

        this.host = host;
        this.repeat_count = repeat_count;
        this.data_block_size = data_block_size;
        this.dscp = dscp;
        this.interval_time_out = interval_time_out;

        return true;
    }

    public void get_results(out string status, out string additional_info,
                            out uint success_count, out uint failure_count,
                            out uint32 average_response_time,
                            out uint32 min_response_time,
                            out uint32 max_response_time) {
        stdout.printf("*Ping* get_results()\n");

        status = this.status;
        additional_info = this.additional_info;
        success_count = this.success_count;
        failure_count = this.failure_count;
        average_response_time = this.average_response_time;
        min_response_time = this.min_response_time;
        max_response_time = this.max_response_time;
    }
}
