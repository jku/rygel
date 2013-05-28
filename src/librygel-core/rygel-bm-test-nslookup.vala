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

// Helper class for BMTestNSLookup.
internal class Rygel.BMTestNSLookup : BMTest {

    private string hostname;
    private string dns_server;
    private uint repeat_count;
    private uint32 interval_time_out;

    private string status;
    private string additional_info;
    private uint success_count;
    private string result;

    private static const uint NSLOOKUP_MIN_REPEAT_COUNT = 1;
    private static const uint NSLOOKUP_MAX_REPEAT_COUNT = 100;
    private static const uint NSLOOKUP_DEFAULT_REPEAT_COUNT = 1;
    private static const uint NSLOOKUP_MIN_REQUEST_INTERVAL_TIMEOUT = 1000;
    private static const uint NSLOOKUP_MAX_REQUEST_INTERVAL_TIMEOUT = 30000;
    private static const uint NSLOOKUP_DEFAULT_REQUEST_INTERVAL_TIMEOUT = 10000;
    private static const uint NSLOOKUP_MAX_RESULT_ANSWER_STR_SIZE = 32;
    private static const uint NSLOOKUP_MAX_RESULT_NAME_STR_SIZE = 256;
    private static const uint NSLOOKUP_MAX_RESULT_IPS_STR_SIZE = 1024;
    private static const uint NSLOOKUP_MAX_RESULT_ARRAY_SIZE = 7;

    public BMTestNSLookup() {
        base("NSLookup");
    }

    public override void execute() {
        stdout.printf("*NSLookup* execute()\n");
    }

    public override void cancel() {
        stdout.printf("*NSLookup* cancel()\n");
    }

    public bool init(string hostname, string dns_server, uint repeat_count,
                     uint32 interval_time_out) {
        stdout.printf("*NSLookup* init()\n");

        if (hostname == null) {
            return false;
        }

        if (dns_server == null) {
            return false;
        }

        if (repeat_count == 0) {
            repeat_count = NSLOOKUP_DEFAULT_REPEAT_COUNT;
        } else if (repeat_count < NSLOOKUP_MIN_REPEAT_COUNT &&
                   repeat_count > NSLOOKUP_MAX_REPEAT_COUNT) {
            return false;
        }

        if (interval_time_out == 0) {
            interval_time_out = NSLOOKUP_DEFAULT_REQUEST_INTERVAL_TIMEOUT;
        } else if (interval_time_out < NSLOOKUP_MIN_REQUEST_INTERVAL_TIMEOUT &&
                   interval_time_out > NSLOOKUP_MAX_REQUEST_INTERVAL_TIMEOUT) {
            return false;
        }

        this.hostname = hostname;
        this.dns_server = dns_server;
        this.repeat_count = repeat_count;
        this.interval_time_out = interval_time_out;

        return true;
    }

    public void get_results(out string status, out string additional_info,
                            out uint success_count, out string result) {
        stdout.printf("*NSLookup* get_results()\n");

        status = this.status;
        additional_info = this.additional_info;
        success_count = this.success_count;
        result = this.result;
    }
}
