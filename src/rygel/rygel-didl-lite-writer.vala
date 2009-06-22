/*
 * Copyright (C) 2009 Nokia Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
 *                               <zeeshan.ali@nokia.com>
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

using GUPnP;
using Gee;

internal errordomain Rygel.DIDLLiteWriterError {
    UNSUPPORTED_OBJECT
}

/**
 * Responsible for serializing media objects.
 */
internal class Rygel.DIDLLiteWriter : GUPnP.DIDLLiteWriter {
    private Rygel.HTTPServer http_server;

    public DIDLLiteWriter (HTTPServer http_server) {
        this.http_server = http_server;
    }

    public void serialize (MediaObject media_object,
                           string      filter_str)
                           throws Error {
        var filter = new Filter (filter_str);

        if (media_object is MediaItem) {
            this.serialize_item ((MediaItem) media_object, filter);
        } else if (media_object is MediaContainer) {
            this.serialize_container ((MediaContainer) media_object, filter);
        } else {
            throw new DIDLLiteWriterError.UNSUPPORTED_OBJECT (
                "Unable to serialize unsupported object");
        }
    }

    private void serialize_item (MediaItem item, Filter filter) throws Error {
        this.start_item (item.id,
                         item.parent.id,
                         null,
                         false);

        /* Add fields */
        this.add_string ("title",
                         GUPnP.DIDLLiteWriter.NAMESPACE_DC,
                         null,
                         item.title);

        if (filter.have ("class", NAMESPACE_UPNP)) {
            this.add_string ("class",
                             GUPnP.DIDLLiteWriter.NAMESPACE_UPNP,
                             null,
                             item.upnp_class);
        }

        if (item.author != null && item.author != "") {
            if (filter.have ("creator", NAMESPACE_UPNP)) {
                this.add_string ("creator",
                                 GUPnP.DIDLLiteWriter.NAMESPACE_DC,
                                 null,
                                 item.author);
            }

            if (item.upnp_class.has_prefix (MediaItem.VIDEO_CLASS) &&
                filter.have ("author", NAMESPACE_UPNP)) {
                this.add_string ("author",
                                 GUPnP.DIDLLiteWriter.NAMESPACE_UPNP,
                                 null,
                                 item.author);
            } else if (item.upnp_class.has_prefix (MediaItem.MUSIC_CLASS) &&
                       filter.have ("artist", NAMESPACE_UPNP)) {
                this.add_string ("artist",
                                 GUPnP.DIDLLiteWriter.NAMESPACE_UPNP,
                                 null,
                                 item.author);
            }
        }

        if (item.track_number >= 0 &&
            filter.have ("originalTrackNumber", NAMESPACE_UPNP)) {
            this.add_int ("originalTrackNumber",
                          GUPnP.DIDLLiteWriter.NAMESPACE_UPNP,
                          null,
                          item.track_number);
        }

        if (item.album != null && item.album != "" &&
            filter.have ("album", NAMESPACE_UPNP)) {
            this.add_string ("album",
                             GUPnP.DIDLLiteWriter.NAMESPACE_UPNP,
                             null,
                             item.album);
        }

        if (item.date != null && item.date != "" &&
            filter.have ("date", NAMESPACE_DC)) {
            this.add_string ("date",
                             GUPnP.DIDLLiteWriter.NAMESPACE_DC,
                             null,
                             item.date);
        }

        if (filter.have ("res", null)) {
            /* Add resource data */
            var resources = this.get_original_resources (item);

            /* Now get the transcoded/proxy URIs */
            this.http_server.add_resources (resources, item);

            foreach (DIDLLiteResource res in resources) {
                this.add_res (res);
            }
        }

        /* End of item */
        this.end_item ();
    }

    private void serialize_container (MediaContainer container,
                                      Filter         filter)
                                      throws Error {
        string parent_id;

        if (container.parent != null) {
            parent_id = container.parent.id;
        } else {
            parent_id = "-1";
        }

        this.start_container (container.id,
                              parent_id,
                              (int) container.child_count,
                              false,
                              false);
        if (filter.have ("class", NAMESPACE_UPNP)) {
            this.add_string ("class",
                             GUPnP.DIDLLiteWriter.NAMESPACE_UPNP,
                             null,
                             "object.container.storageFolder");
        }

        this.add_string ("title",
                         GUPnP.DIDLLiteWriter.NAMESPACE_DC,
                         null,
                         container.title);

        /* End of Container */
        this.end_container ();
    }

    private ArrayList<DIDLLiteResource?> get_original_resources (MediaItem item)
                                                                 throws Error {
        var resources = new ArrayList<DIDLLiteResource?> ();

        foreach (var uri in item.uris) {
            DIDLLiteResource res = item.create_res (uri);

            resources.add (res);
        }

        return resources;
    }
}

private class Rygel.Filter : ArrayList<string> {
    public Filter (string filter_str) {
        base ((GLib.EqualFunc) Filter.filter_equal_func);

        var tokens = filter_str.split (",", -1);

        foreach (var token in tokens) {
            this.add (token);
        }
    }

    public bool have (string prop, string? prefix) {
        if (prefix != null) {
            return (prefix + ":" + prop) in this;
        } else {
            return (prop in this);
        }
    }

    private static bool filter_equal_func (string a, string b) {
        return a == "*" || a == b;
    }
}

