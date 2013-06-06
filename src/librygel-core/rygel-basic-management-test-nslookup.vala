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

internal class Rygel.BasicManagementTestNSLookup : BasicManagementTest {
    private const string HEADER =
        "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
        "<bms:NSLookupResult " +
            "xmlns:bms=\"urn:schemas-upnp-org:dm:bms\" " +
            "xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" " +
            "xsi:schemaLocation=\"" +
                "urn:schemas-upnp-org:dm:bms " +
                "http://www.upnp.org/schemas/dm/bms.xsd\">\n";

    private const string FOOTER = "</bms:NSLookupResult>\n";

    private enum ProcessState {
        INIT,
        SERVER,
        NAME,
    }

    private enum GenericStatus {
        SUCCESS,
        ERROR_DNS_SERVER_NOT_RESOLVED,
        ERROR_INTERNAL,
        ERROR_OTHER;
        
        public string to_string() {
            switch (this) {
                case SUCCESS:
                    return "Success";
                case ERROR_DNS_SERVER_NOT_RESOLVED:
                    return "Error_DNSServerNotResolved";
                case ERROR_INTERNAL:
                    return "Error_Internal";
                case ERROR_OTHER:
                    return "Error_Other";
                default:
                    assert_not_reached();
            }
        }
    }

    private enum ResultStatus {
        SUCCESS,
        ERROR_DNS_SERVER_NOT_AVAILABLE,
        ERROR_HOSTNAME_NOT_RESOLVED,
        ERROR_TIMEOUT,
        ERROR_OTHER;

        public string to_string() {
            switch (this) {
                case SUCCESS:
                    return "Success";
                case ERROR_DNS_SERVER_NOT_AVAILABLE:
                    return "Error_DNSServerNotAvailable";
                case ERROR_HOSTNAME_NOT_RESOLVED:
                    return "Error_HostNameNotResolved";
                case ERROR_TIMEOUT:
                    return "Error_Timeout";
                case ERROR_OTHER:
                    return "Error_Other";
                default:
                    assert_not_reached();
            }
        }
    }

    private enum AnswerType {
        NONE,
        AUTHORITATIVE,
        NON_AUTHORITATIVE;

        public string to_string() {
            switch (this) {
                case NONE:
                    return "None";
                case AUTHORITATIVE:
                    return "Authoritative";
                case NON_AUTHORITATIVE:
                    return "NonAuthoritative";
                default:
                    assert_not_reached();
            }
        }
    }

    private static const uint MAX_REPETITIONS = 100;
    private static const uint DEFAULT_REPETITIONS = 1;
    private static const uint MIN_INTERVAL_TIMEOUT = 1000;
    private static const uint MAX_INTERVAL_TIMEOUT = 30000;
    private static const uint DEFAULT_INTERVAL_TIMEOUT = 1000;

    private struct Result {
        private ProcessState state;
        private string name_server_address;
        private string returned_host_name;
        private string[] addresses;
        private ResultStatus status;
        private AnswerType answer_type;
        uint execution_time;

        private string get_addresses_csv () {
            var builder = new StringBuilder ("");
            foreach (var address in this.addresses) {
                if (builder.len != 0)
                    builder.append (",");
                builder.append (address);
            }

            return builder.str;
        }

        public string to_xml_fragment() {
            /* TODO limit the returned values */
            return ("<Result>\n" +
                    "<Status>%s</Status>\n" +
                    "<AnswerType>%s</AnswerType>\n" +
                    "<HostNameReturned>%s</HostNameReturned>\n" +
                    "<IPAddresses>%s</IPAddresses>\n" +
                    "<DNSServerIP>%s</DNSServerIP>\n" +
                    "<ResponseTime>%u</ResponseTime>\n" +
                    "</Result>\n").printf (this.status.to_string(),
                                           this.answer_type.to_string(),
                                           this.returned_host_name,
                                           this.get_addresses_csv (),
                                           this.name_server_address,
                                           this.execution_time); 
        }
    }

    public string host_name { construct; private get; default = ""; }
    public string? name_server { construct; private get; default = null; }

    private uint _interval_time_out;
    public uint interval_time_out {
        construct {
            this._interval_time_out = value;
            if (this._interval_time_out == 0)
                this._interval_time_out = DEFAULT_INTERVAL_TIMEOUT;
        }
        private get {
            return this._interval_time_out;
        }
        default = DEFAULT_INTERVAL_TIMEOUT;
    }

    public uint repetitions {
        construct {
            this.iterations = value;
            if (this.iterations == 0)
                this.iterations = DEFAULT_REPETITIONS;
        }
        private get {
            return this.iterations;
        }
        default = DEFAULT_REPETITIONS;
    }

    private Result[] results;
    private GenericStatus generic_status;
    private string additional_info;
    private Timer timer = new Timer ();

    public override string method_type { get { return "NSLookup"; } }
    public override string results_type { get { return "GetNSLookupResult"; } }

    public BasicManagementTestNSLookup(string host_name,
                                       string? name_server,
                                       uint repetitions,
                                       uint32 interval_time_out) {
        Object (host_name: host_name,
                name_server: name_server,
                repetitions: repetitions,
                interval_time_out: interval_time_out);
    }

    public override void constructed () {
        base.constructed ();

        this.generic_status = GenericStatus.ERROR_INTERNAL;
        this.additional_info = "";
        this.results = {};

        this.command = { "nslookup" };
        this.command += ("-timeout=%u").printf (this.interval_time_out/1000);
        this.command += host_name;
        if (name_server != null && name_server.length > 0)
            this.command += name_server;

        /* Fail early if internal parameter limits are violated */
        if (this.repetitions > MAX_REPETITIONS) {
            init_state = InitState.INVALID_PARAMETER;
            var msg = "NumberOfRepetitions %u is not in allowed range [0, %u]";
            this.additional_info = msg.printf (this.repetitions,
                                               MAX_REPETITIONS);
        } else if (this.interval_time_out < MIN_INTERVAL_TIMEOUT ||
                   this.interval_time_out > MAX_INTERVAL_TIMEOUT) {
            init_state = InitState.INVALID_PARAMETER;
            var msg = "Timeout %u is not in allowed range [%u, %u]";
            this.additional_info = msg.printf (this.interval_time_out,
                                               MIN_INTERVAL_TIMEOUT,
                                               MAX_INTERVAL_TIMEOUT);
        }
    }

    protected override void init_iteration () {
        base.init_iteration ();
        var result = Result () {
            state = ProcessState.INIT,
            name_server_address = "",
            returned_host_name = "",
            addresses = {},
            status = ResultStatus.ERROR_OTHER,
            answer_type = AnswerType.NONE,
            execution_time = 0
        };
        this.results += result;

        this.timer.start ();
    }

    protected override void finish_iteration () {
        switch (this.init_state) {
            case InitState.SPAWN_FAILED:
                /* quitting early */
                this.generic_status = GenericStatus.ERROR_INTERNAL;
                this.additional_info = "Failed to spawn nslookup";
                this.results[results.length - 1].status = 
                                        ResultStatus.ERROR_OTHER;
                break;
            case InitState.INVALID_PARAMETER:
                /* quitting early */
                /* constructed() has set info already */
                this.generic_status = GenericStatus.ERROR_OTHER;
                this.results[results.length - 1].status = 
                                        ResultStatus.ERROR_OTHER;
                break;
            default:
                var elapsed_msec = this.timer.elapsed (null) * 1000;
                var execution_time = (uint)Math.round(elapsed_msec);
                this.results[results.length - 1].execution_time = execution_time;
                break;
        }

        base.finish_iteration ();
    }

    protected override void handle_error (string line) {
        var result = this.results[results.length - 1];

        if (line.contains ("couldn't get address for")) {
            this.generic_status = GenericStatus.ERROR_DNS_SERVER_NOT_RESOLVED;
            this.execution_state = ExecutionState.COMPLETED;
            result.status = ResultStatus.ERROR_DNS_SERVER_NOT_AVAILABLE;
        }

        /* there has to be a nicer way to do this... */
        this.results[results.length - 1] = result;
    }

    protected override void handle_output (string line) {
        var result = this.results[results.length - 1];
        line.strip ();
        if (line.has_prefix ("Server:")) {
            if (result.state != ProcessState.INIT)
                warning ("nslookup parser: Unexpected 'Server:' line.\n");
            result.state = ProcessState.SERVER;
        } else if (line.has_prefix ("Name:")) {
            if (result.state == ProcessState.INIT)
                warning ("nslookup parser: Unexpected 'Name:' line");
            else if (result.state == ProcessState.SERVER)
                result.returned_host_name =
                                        line.substring ("Name:".length).strip ();
            result.state = ProcessState.NAME;
        } else if (line.has_prefix ("Address:")) {
            if (result.state == ProcessState.SERVER) {
                var address = line.substring ("Address:".length).strip ();
                result.name_server_address = address.split ("#", 2)[0];
                this.generic_status = GenericStatus.SUCCESS;
            } else if (result.state == ProcessState.NAME) {
                result.addresses += line.substring ("Address:".length).strip ();
                result.status = ResultStatus.SUCCESS;
                if (result.answer_type == AnswerType.NONE)
                    result.answer_type = AnswerType.AUTHORITATIVE;
            } else
                warning ("nslookup parser: Unexpected 'Address:' line");
        } else if (line.has_prefix ("Non-authoritative answer:")) {
            result.answer_type = AnswerType.NON_AUTHORITATIVE;
        } else if (line.contains ("server can't find")) {
            result.status = ResultStatus.ERROR_HOSTNAME_NOT_RESOLVED;
        } else if (line.contains ("couldn't get address for")) {
            this.generic_status = GenericStatus.ERROR_DNS_SERVER_NOT_RESOLVED;
            result.status = ResultStatus.ERROR_DNS_SERVER_NOT_AVAILABLE;
            this.execution_state = ExecutionState.COMPLETED;
        } else if (line.contains ("no servers could be reached")) {
            result.status = ResultStatus.ERROR_DNS_SERVER_NOT_AVAILABLE;
        }

        /* there has to be a nicer way to do this... */
        this.results[results.length - 1] = result;
    }


    public void get_results(out string status, out string additional_info,
                            out uint success_count, out string result_string) {
        success_count = 0;
        StringBuilder builder = new StringBuilder (HEADER);

        foreach (var result in this.results) {
            builder.append (result.to_xml_fragment ());
            if (result.status == ResultStatus.SUCCESS)
                success_count++;
        }
        builder.append (FOOTER);
        result_string = builder.str;

        status = this.generic_status.to_string();
        additional_info = this.additional_info;
    }

/*
    //valac --pkg gio-2.0 --pkg posix -X -lm  rygel-bm-test-nslookup.vala rygel-bm-test.vala

    private static int main(string[] args) {
        MainLoop loop = new MainLoop();
        BasicManagementTestNSLookup nslookup = new BasicManagementTestNSLookup ();

        if (args.length < 2) {
            print ("Usage: %s <hostname> [<nameserver> [<repetitions> [<timeout>]]]\n", args[0]);
            return 0;
        }
        
        try {
            nslookup.init (args[1],
                           args.length > 2 ? args[2] : null,
                           args.length > 3 ? int.parse (args[3]): 0,
                           args.length > 4 ? int.parse (args[4]) : 0);
        } catch (BasicManagementTestError e) {
            warning ("Incorrect parameters");
        }

        nslookup.execute.begin((obj, res)=> {
            try {
                string status;
                string info;
                string results;
                uint count;
                nslookup.execute.end(res);
                nslookup.get_results (out status, out info, out count, out results);
                print ("\nStatus: %s, %u successful iterations.\nResults:\n%s", status, count, results);
            } catch (Error e) {
                print ("Oops: %s\n", e.message);
            }
            loop.quit();
        });
        loop.run();

        return 0;
    }
*/
}
