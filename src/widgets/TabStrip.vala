/* TabStrip.vala
 *
 * Copyright 2026 Aaron Sherrill
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

/**
 * Places a widget directly after the last tab of an Adw.TabBar.
 *
 * Adw.TabBar only offers action widgets at its outer edges. TabStrip reserves
 * room for the trailing widget beside the tab bar, then moves the trailing
 * widget into the tab bar's empty space so that it follows the last tab. When
 * the tabs fill the bar, the trailing widget rests in the reserved room.
 */
public class Terminal.TabStrip : Gtk.Widget {

  private Adw.TabBar? _tab_bar = null;
  private Gtk.Widget? _trailing_widget = null;

  // Distance from the tab bar's leading edge to the trailing widget, as of
  // the last allocation.
  private int trailing_offset = 0;

  public Adw.TabBar? tab_bar {
    get { return this._tab_bar; }
    set {
      this._tab_bar?.unparent ();
      this._tab_bar = value;
      value?.insert_before (this, this._trailing_widget);
    }
  }

  public Gtk.Widget? trailing_widget {
    get { return this._trailing_widget; }
    set {
      this._trailing_widget?.unparent ();
      this._trailing_widget = value;
      // Last child, so it draws and receives input above the tab bar.
      value?.insert_before (this, null);
    }
  }

  static construct {
    set_css_name ("tabstrip");
  }

  public override void dispose () {
    this.tab_bar = null;
    this.trailing_widget = null;
    base.dispose ();
  }

  public override Gtk.SizeRequestMode get_request_mode () {
    return Gtk.SizeRequestMode.CONSTANT_SIZE;
  }

  public override void measure (
    Gtk.Orientation orientation,
    int for_size,
    out int minimum,
    out int natural,
    out int minimum_baseline,
    out int natural_baseline
  ) {
    minimum = 0;
    natural = 0;
    minimum_baseline = -1;
    natural_baseline = -1;

    for (var c = this.get_first_child (); c != null; c = c.get_next_sibling ()) {
      if (!c.should_layout ()) continue;

      int child_min, child_nat, _min_baseline, _nat_baseline;
      c.measure (
        orientation, -1,
        out child_min, out child_nat,
        out _min_baseline, out _nat_baseline
      );

      if (orientation == Gtk.Orientation.HORIZONTAL) {
        minimum += child_min;
        natural += child_nat;
      }
      else {
        minimum = int.max (minimum, child_min);
        natural = int.max (natural, child_nat);
      }
    }
  }

  public override void size_allocate (int width, int height, int baseline) {
    bool is_rtl = this.get_direction () == Gtk.TextDirection.RTL;
    int trailing_width = 0;

    if (this._trailing_widget?.should_layout () ?? false) {
      int _min, _min_baseline, _nat_baseline;
      this._trailing_widget.measure (
        Gtk.Orientation.HORIZONTAL, -1,
        out _min, out trailing_width,
        out _min_baseline, out _nat_baseline
      );
    }

    int bar_width = width - trailing_width;

    if (this._tab_bar?.should_layout () ?? false) {
      this._tab_bar.allocate (
        bar_width, height, baseline,
        translate (is_rtl ? trailing_width : 0)
      );
    }

    this.trailing_offset = this.find_trailing_offset ();

    if (this._trailing_widget?.should_layout () ?? false) {
      int x = is_rtl
        ? bar_width - this.trailing_offset
        : this.trailing_offset;

      this._trailing_widget.allocate (
        trailing_width, height, baseline, translate (x)
      );
    }
  }

  public override void snapshot (Gtk.Snapshot snapshot) {
    // Tab animations move tabs without reallocating this widget, but every
    // frame they move in redraws it. Follow the last tab from here.
    if (this.find_trailing_offset () != this.trailing_offset) {
      this.queue_allocate ();
    }

    base.snapshot (snapshot);
  }

  /**
   * Returns the distance from the tab bar's leading edge to the trailing edge
   * of its last tab, limited to the tab bar's width.
   */
  private int find_trailing_offset () {
    if (this._tab_bar == null) return 0;

    bool is_rtl = this.get_direction () == Gtk.TextDirection.RTL;
    int bar_width = this._tab_bar.get_width ();
    float edge = 0;

    this.each_tab (this._tab_bar, (tab) => {
      Graphene.Rect bounds;
      if (!tab.compute_bounds (this._tab_bar, out bounds)) return;

      float tab_edge = is_rtl
        ? bar_width - bounds.get_x ()
        : bounds.get_x () + bounds.get_width ();

      edge = float.max (edge, tab_edge);
    });

    return ((int) Math.ceilf (edge)).clamp (0, bar_width);
  }

  private delegate void TabFunc (Gtk.Widget tab);

  // Adw.Tab is private to libadwaita, so tabs are found by their CSS name.
  private void each_tab (Gtk.Widget parent, TabFunc func) {
    for (var c = parent.get_first_child (); c != null; c = c.get_next_sibling ()) {
      if (c.get_css_name () == "tab") {
        func (c);
      }
      else {
        this.each_tab (c, func);
      }
    }
  }

  private static Gsk.Transform translate (int x) {
    return new Gsk.Transform ().translate ({ x, 0 });
  }
}
