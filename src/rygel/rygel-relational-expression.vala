/*
 * Copyright (C) 2009 Nokia Corporation.
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org>
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

// Represents a search expression that consists of two strings joined by a
// relational operator.
public class Rygel.RelationalExpression :
             Rygel.SearchExpression<SearchCriteriaOp,string,string> {
    internal const string CAPS = "@id,@parentID,upnp:class," +
                                 "dc:title,upnp:artist,upnp:album," +
                                 "dc:creator,upnp:createClass";

    public override bool satisfied_by (MediaObject media_object) {
        switch (this.operand1) {
        case "@id":
            return this.compare_string (media_object.id);
        case "@parentID":
            return this.compare_string (media_object.parent.id);
        case "upnp:class":
            return this.compare_string (media_object.upnp_class);
        case "dc:title":
            return this.compare_string (media_object.title);
        case "upnp:createClass":
            if (!(media_object is WritableContainer)) {
                return false;
            }

            return this.compare_create_class (
                                        media_object as WritableContainer);
        case "dc:creator":
            if (!(media_object is PhotoItem)) {
                return false;
            }

            return this.compare_string ((media_object as PhotoItem).creator);
        case "upnp:artist":
            if (!(media_object is MusicItem)) {
                return false;
            }

            return this.compare_string ((media_object as MusicItem).artist);
        case "upnp:album":
            if (!(media_object is MusicItem)) {
                return false;
            }

            return this.compare_string ((media_object as MusicItem).album);
        default:
            return false;
        }
    }

    public override string to_string () {
        return "%s %d %s".printf (this.operand1, this.op, this.operand2);
    }

    private bool compare_create_class (WritableContainer container) {
        var ret = false;

        foreach (var create_class in container.create_classes) {
            if (this.compare_string (create_class)) {
                ret = true;

                break;
            }
        }

        return ret;
    }

    public bool compare_string (string? str) {
        var up_operand2 = this.operand2.up ();
        var up_str = str.up ();

        switch (this.op) {
        case SearchCriteriaOp.EXISTS:
            if (this.operand2 == "true") {
                return str != null;
            } else {
                return str == null;
            }
        case SearchCriteriaOp.EQ:
            return up_operand2 == up_str;
        case SearchCriteriaOp.CONTAINS:
            return up_str.contains (up_operand2);
        case SearchCriteriaOp.DERIVED_FROM:
            return up_str.has_prefix (up_operand2);
        default:
            return false;
        }
    }
}
