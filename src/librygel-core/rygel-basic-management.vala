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

    private HashMap<string, BasicManagementTest> tests_map;
    private HashMap<string, BasicManagementTest> active_tests_map;

    private static uint current_id = 0;

    protected string device_status;

    public override void constructed () {
        base.constructed ();

        this.tests_map = new HashMap<string, BasicManagementTest> ();
        this.active_tests_map = new HashMap<string, BasicManagementTest> ();

        var now = TimeVal ();
        now.tv_usec = 0;

        this.device_status = "OK," + now.to_iso8601 ();

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

    private string create_test_ids_list (bool active) {
        string test_ids_list = "";
        HashMap<string, BasicManagementTest> test_map;

        if (active) {
            test_map = this.active_tests_map;
        } else {
            test_map = this.tests_map;
        }

        foreach (string key in test_map.keys) {
            if (test_ids_list == "") {
                test_ids_list = key;
            } else {
                test_ids_list += "," + key;
            }
        }

        return test_ids_list;
    }

    private void update_test_ids_lists (BasicManagementTest bm_test) {
        BasicManagementTest.ExecutionState execState = bm_test.execState;

        if (execState == BasicManagementTest.ExecutionState.REQUESTED) {
            this.tests_map.set (bm_test.id, bm_test);
            this.notify ("TestIDs", typeof (string),
                         create_test_ids_list (false));

            this.active_tests_map.set (bm_test.id, bm_test);
            this.notify ("ActiveTestIDs", typeof (string),
                         create_test_ids_list (true));
        } else if ((execState == BasicManagementTest.ExecutionState.CANCELED) ||
                   (execState == BasicManagementTest.ExecutionState.COMPLETED) ||
                   (execState == BasicManagementTest.ExecutionState.SPAWN_FAILED)) {
            this.active_tests_map.unset (bm_test.id);
            this.notify ("ActiveTestIDs", typeof (string),
                         create_test_ids_list (true));
        }
    }

    private void notify_test_exec_state_changed_cb (Object object,
                                                         ParamSpec p) {
        update_test_ids_lists (object as BasicManagementTest);
    }

    private void add_test_and_return_action (BasicManagementTest bm_test,
                                             ServiceAction action) {
        current_id++;

        bm_test.id = current_id.to_string ();

        update_test_ids_lists (bm_test);

        bm_test.notify["execState"].connect (this.notify_test_exec_state_changed_cb);

        /* TODO: decide if test should really execute now */

        bm_test.execute.begin ((obj,res) => {
            try {
                bm_test.execute.end (res);
            } catch (BasicManagementTestError e) {
                /* already executing */
            }
            /* TODO Test is finished, now remove test from active test list */
        });

        action.set ("TestID",
                        typeof (string),
                        bm_test.id);

        action.return ();
    }

/*
    /// TODO: NOT USED YET
    private void remove_test (BasicManagementTest bm_test) {
        if (this.tests_map.unset (bm_test.id) == true) {
            this.notify ("TestIDs", typeof (string),
                         create_test_ids_list (false));
        }

        if (this.active_tests_map.unset (bm_test.id) == true) {
            this.notify ("ActiveTestIDs", typeof (string),
                         create_test_ids_list (true));
        }
    }
*/

    // Error out if 'TestID' is wrong
    private bool ensure_test_exists (ServiceAction action,
                                     out BasicManagementTest bm_test) {

        string test_id;

        action.get ("TestID", typeof (string), out test_id);

        bm_test = this.tests_map[test_id];

        if (bm_test == null) {
            /// No test with the specified TestID was found
            action.return_error (706, _("No Such Test"));

            return false;
        } else if ((bm_test.results_type != action.get_name()) &&
                   ((action.get_name() == "GetPingResult") ||
                    (action.get_name() == "GetNSLookupResult") ||
                    (action.get_name() == "GetTracerouteResult"))) {
            /// TestID is valid but refers to the wrong test type
            action.return_error (707, _("Wrong Test Type"));

            return false;
        } else if ((bm_test.execState != BasicManagementTest.ExecutionState.COMPLETED) &&
                   ((action.get_name() == "GetPingResult") ||
                    (action.get_name() == "GetNSLookupResult") ||
                    (action.get_name() == "GetTracerouteResult"))) {
            /// TestID is valid but the test Results are not available
            action.return_error (708, _("Invalid Test State"));

            return false;
        } else if ((action.get_name() == "CancelTest") &&
                   ((bm_test.execState == BasicManagementTest.ExecutionState.CANCELED) ||
                    (bm_test.execState == BasicManagementTest.ExecutionState.COMPLETED))) {
            /// TestID is valid but the test can't be canceled
            action.return_error (709, _("State Precludes Cancel"));

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
        val.set_string (create_test_ids_list (false));
    }

    private void query_active_test_ids_cb (Service   cm,
                                           string    var,
                                           ref Value val) {
        val.init (typeof (string));
        val.set_string (create_test_ids_list (true));
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

        BasicManagementTestPing ping = new BasicManagementTestPing();
        if (!ping.init (host, repeat_count, interval_time_out,
                        data_block_size, dscp)) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        this.add_test_and_return_action (ping as BasicManagementTest, action);
    }

    private void ping_result_cb (Service             cm,
                                 ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BasicManagementTest bm_test;

        if (!this.ensure_test_exists (action, out bm_test)) {
            return;
        }

        string status, additional_info;
        uint success_count, failure_count;
        uint32 average_response_time, min_response_time, max_response_time;

        (bm_test as BasicManagementTestPing).get_results (out status,
                                             out additional_info,
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
                        typeof (uint),
                        out repeat_count,
                    "Timeout",
                        typeof (uint32),
                        out interval_time_out);

        BasicManagementTestNSLookup nslookup;
        nslookup = new BasicManagementTestNSLookup();
        try {
            nslookup.init (hostname, dns_server,
                           repeat_count, interval_time_out);

            this.add_test_and_return_action (nslookup as BasicManagementTest,
                                             action);
        } catch (BasicManagementTestError e) {
            action.return_error (402, _("Invalid argument"));
        }
    }

    private void nslookup_result_cb (Service             cm,
                                     ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BasicManagementTest bm_test;

        if (!this.ensure_test_exists (action, out bm_test)) {
            return;
        }

        string status, additional_info, result;
        uint success_count;

        (bm_test as BasicManagementTestNSLookup).get_results (out status,
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

        BasicManagementTestTraceroute traceroute;
        traceroute = new BasicManagementTestTraceroute();
        if (!traceroute.init (host, wait_time_out, data_block_size,
                              max_hop_count, dscp)) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        this.add_test_and_return_action (traceroute as BasicManagementTest,
                                         action);
    }

    private void traceroute_result_cb (Service             cm,
                                       ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BasicManagementTest bm_test;

        if (!this.ensure_test_exists (action, out bm_test)) {
            return;
        }

        string status, additional_info, hop_hosts;
        uint32 response_time;

        (bm_test as BasicManagementTestTraceroute).get_results (out status,
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
                        create_test_ids_list (false));

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
                        create_test_ids_list (true));

        action.return ();
    }

    private void get_test_info_cb (Service             cm,
                                   ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BasicManagementTest bm_test;

        if (!this.ensure_test_exists (action, out bm_test)) {
            return;
        }

        action.set ("Type",
                        typeof (string),
                        bm_test.method_type,
                    "State",
                        typeof (string),
                        bm_test.execState.to_string());

        action.return ();
    }

    private void cancel_test_cb (Service             cm,
                                 ServiceAction action) {
        if (action.get_argument_count () != 1) {
            action.return_error (402, _("Invalid argument"));

            return;
        }

        BasicManagementTest bm_test;

        if (!this.ensure_test_exists (action, out bm_test)) {
            return;
        }

        try {
            bm_test.cancel();
        } catch (BasicManagementTestError e) {
            warning ("Canceled test was not running\n");
        }

        action.return ();
    }
}
