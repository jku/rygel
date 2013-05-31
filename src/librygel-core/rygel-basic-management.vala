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

using Gee;
using GLib;
using GUPnP;

/**
 * Basic implementation of UPnP BasicManagement service version 2.
 */
public class Rygel.BasicManagement : Service {
    public const string UPNP_ID = "urn:upnp-org:serviceId:BasicManagement";
    public const string UPNP_TYPE =
                        "urn:schemas-upnp-org:service:BasicManagement:2";
    public const string DESCRIPTION_PATH = "xml/BasicManagement2.xml";

    private LinkedList<BMTest> tests_list;
    private LinkedList<BMTest> active_tests_list;

    private static uint current_id = 0;

    protected string device_status;
    protected string test_ids;
    protected string active_test_ids;

    public override void constructed () {
        base.constructed ();

        this.tests_list = new LinkedList<BMTest> ();
        this.active_tests_list = new LinkedList<BMTest> ();

        this.device_status   = "OK,2009-06-15T12:00:00,Details";
        this.test_ids        = "";
        this.active_test_ids = "";

        this.query_variable["DeviceStatus"].connect
                                        (this.query_device_status_cb);
        this.query_variable["TestIDs"].connect
                                        (this.query_test_ids_cb);
        this.query_variable["ActiveTestIDs"].connect
                                        (this.query_active_test_ids_cb);

        this.action_invoked["GetDeviceStatus"].connect
                                        (this.get_device_status_cb);
        this.action_invoked["Ping"].connect
                                        (this.ping_cb);
        this.action_invoked["GetPingResult"].connect
                                        (this.ping_result_cb);
        this.action_invoked["NSLookup"].connect
                                        (this.nslookup_cb);
        this.action_invoked["GetNSLookupResult"].connect
                                        (this.nslookup_result_cb);
        this.action_invoked["Traceroute"].connect
                                        (this.traceroute_cb);
        this.action_invoked["GetTracerouteResult"].connect
                                        (this.traceroute_result_cb);
        this.action_invoked["GetTestIDs"].connect
                                        (this.get_test_ids_cb);
        this.action_invoked["GetActiveTestIDs"].connect
                                        (this.get_active_test_ids_cb);
        this.action_invoked["GetTestInfo"].connect
                                        (this.get_test_info_cb);
        this.action_invoked["CancelTest"].connect
                                        (this.cancel_test_cb);
    }

    private void add_test_and_return_action (BMTest bm_test, ServiceAction action) {
        current_id++;
        bm_test.id = current_id.to_string ();

        this.tests_list.add (bm_test);

        this.test_ids = "";
        foreach (BMTest test in this.tests_list) {
             if (this.test_ids == "") {
                 this.test_ids = test.id;
             } else {
                 this.test_ids += "," + test.id;
             }
        }

        /* TODO: decide if test should really execute now */

        bm_test.execute.begin ((obj,res) => {
            try {
                bm_test.execute.end (res);
            } catch (BMTestError e) {
                /* already executing */
            }
            /* TODO Test is finished, now remove test from active test list */
        });

        action.set ("TestID",
                        typeof (string),
                        bm_test.id);
        action.return ();
    }

    // Error out if 'TestID' is wrong
    private bool check_test_id (ServiceAction action, out BMTest bm_test) {

        string test_id;

        action.get ("TestID", typeof (string), out test_id);

        bm_test = null;

        foreach (BMTest test in this.tests_list) {
             if (test.id == test_id) {
                 bm_test = test;

                 break;
             }
        }

        if (bm_test == null) {
            // No test with the specified TestID was found
            action.return_error (706, _("No Such Test"));

            return false;
        } else if ((action.get_name() != "CancelTest") &&
                   (action.get_name() != "GetTestInfo") &&
                   (bm_test.type != action.get_name())) {
            // TestID is valid but refers to the wrong test type
            action.return_error (707, _("Wrong Test Type"));

            return false;
        } else if ((action.get_name() != "GetTestInfo") &&
                   (bm_test.execution_state != BMTest.ExecutionState.COMPLETED)) {
            // TestID is valid but the test Results are not available
            action.return_error (708, _("Invalid Test State"));

            return false;
        }

        return true;
    }

    private void query_device_status_cb (Service   cm,
                                         string    var,
                                         ref Value val) {
        val.init (typeof (string));
        val.set_string (device_status);
    }

    private void query_test_ids_cb (Service   cm,
                                    string    var,
                                    ref Value val) {
        val.init (typeof (string));
        val.set_string (test_ids);
    }

    private void query_active_test_ids_cb (Service   cm,
                                           string    var,
                                           ref Value val) {
        val.init (typeof (string));
        val.set_string (active_test_ids);
    }

    private void get_device_status_cb (Service             cm,
                                       ServiceAction action) {
        if (action.get_argument_count () != 0) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        action.set ("DeviceStatus",
                        typeof (string),
                        this.device_status);

        action.return ();
    }

    private void ping_cb (Service             cm,
                          ServiceAction action) {
        if (action.get_argument_count () != 5) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        string host;
        uint repeat_count, data_block_size, dscp;
        uint32 interval_time_out;

        action.get ("Host",
                        typeof (string),
                        out host,
                    "NumberOfRepetitions",
                        typeof (uint),
                        out repeat_count,
                    "Timeout",
                        typeof (uint32),
                        out interval_time_out,
                    "DataBlockSize",
                        typeof (uint),
                        out data_block_size,
                    "DSCP",
                        typeof (uint),
                        out dscp);

        BMTestPing ping = new BMTestPing();
        if (!ping.init (host, repeat_count, interval_time_out,
                        data_block_size, dscp)) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        // test_id to be added to TestIDs and ActiveTestID
        this.add_test_and_return_action (ping as BMTest, action);
    }

    private void ping_result_cb (Service             cm,
                                 ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BMTest bm_test;

        if (!this.check_test_id (action, out bm_test)) {
            return;
        }

        string status, additional_info;
        uint success_count, failure_count;
        uint32 average_response_time, min_response_time, max_response_time;

        (bm_test as BMTestPing).get_results (out status, out additional_info,
                                             out success_count,
                                             out failure_count,
                                             out average_response_time,
                                             out min_response_time,
                                             out max_response_time);

        action.set ("Status",
                        typeof (string),
                        status,
                    "AdditionalInfo",
                        typeof (string),
                        additional_info,
                    "SuccessCount",
                        typeof (uint),
                        success_count,
                    "FailureCount",
                        typeof (uint),
                        failure_count,
                    "AverageResponseTime",
                        typeof (uint32),
                        average_response_time,
                    "MinimumResponseTime",
                        typeof (uint32),
                        min_response_time,
                    "MaximumResponseTime",
                        typeof (uint32),
                        max_response_time);

        action.return ();
    }

    private void nslookup_cb (Service             cm,
                              ServiceAction action) {
        if (action.get_argument_count () != 4) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        string hostname;
        string dns_server;
        uint repeat_count;
        uint32 interval_time_out;

        action.get ("HostName",
                        typeof (string),
                        out hostname,
                    "DNSServer",
                        typeof (string),
                        out dns_server,
                    "NumberOfRepetitions",
                        typeof (string),
                        out repeat_count,
                    "Timeout",
                        typeof (string),
                        out interval_time_out);


        BMTestNSLookup nslookup = new BMTestNSLookup();
        try {
            nslookup.init (hostname, dns_server,
                           repeat_count, interval_time_out);

            this.add_test_and_return_action (nslookup as BMTest, action);
        } catch (BMTestError e) {
            action.return_error (402, _("Invalid argument"));
        }
    }

    private void nslookup_result_cb (Service             cm,
                                     ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BMTest bm_test;

        if (!this.check_test_id (action, out bm_test)) {
            return;
        }

        string status, additional_info, result;
        uint success_count;

        (bm_test as BMTestNSLookup).get_results (out status,
                                                 out additional_info,
                                                 out success_count,
                                                 out result);

        action.set ("Status",
                        typeof (string),
                        status,
                    "AdditionalInfo",
                        typeof (string),
                        additional_info,
                    "SuccessCount",
                        typeof (uint),
                        success_count,
                    "Result",
                        typeof (string),
                        result);

        action.return ();
    }

    private void traceroute_cb (Service             cm,
                                ServiceAction action) {
        if (action.get_argument_count () != 5) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        string host;
        uint32 wait_time_out;
        uint data_block_size, max_hop_count, dscp;

        action.get ("Host",
                        typeof (string),
                        out host,
                    "Timeout",
                        typeof (uint32),
                        out wait_time_out,
                    "DataBlockSize",
                        typeof (string),
                        out data_block_size,
                    "MaxHopCount",
                        typeof (uint),
                        out max_hop_count,
                    "DSCP",
                        typeof (uint),
                        out dscp);

        BMTestTraceroute traceroute = new BMTestTraceroute();
        if (!traceroute.init (host, wait_time_out, data_block_size,
                              max_hop_count, dscp)) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        this.add_test_and_return_action (traceroute as BMTest, action);
    }

    private void traceroute_result_cb (Service             cm,
                                       ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BMTest bm_test;

        if (!this.check_test_id (action, out bm_test)) {
            return;
        }

        string status, additional_info, hop_hosts;
        uint32 response_time;

        (bm_test as BMTestTraceroute).get_results (out status,
                                                   out additional_info,
                                                   out response_time,
                                                   out hop_hosts);

        action.set ("Status",
                        typeof (string),
                        status,
                    "AdditionalInfo",
                        typeof (string),
                        additional_info,
                    "ResponseTime",
                        typeof (uint32),
                        response_time,
                    "HopHosts",
                        typeof (string),
                        hop_hosts);

        action.return ();
    }

    private void get_test_ids_cb (Service             cm,
                                  ServiceAction action) {
        if (action.get_argument_count () != 0) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        action.set ("TestIDs",
                        typeof (string),
                        this.test_ids);

        action.return ();
    }

    private void get_active_test_ids_cb (Service             cm,
                                         ServiceAction action) {
        if (action.get_argument_count () != 0) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        action.set ("TestIDs",
                        typeof (string),
                        this.active_test_ids);

        action.return ();
    }

    private void get_test_info_cb (Service             cm,
                                   ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BMTest bm_test;

        if (!this.check_test_id (action, out bm_test)) {
            return;
        }

        action.set ("Type",
                        typeof (string),
                        bm_test.type,
                    "State",
                        typeof (string),
                        bm_test.execution_state.to_string());

        action.return ();
    }

    private void cancel_test_cb (Service             cm,
                                 ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BMTest bm_test;

        if (!this.check_test_id (action, out bm_test)) {
            return;
        }

        try {
            bm_test.cancel();
        } catch (BMTestError e) {
            warning ("Canceled test was not running\n");
        }

        action.return ();
    }
}
