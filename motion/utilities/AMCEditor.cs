/*
 * AMCEditor.cs - An editor for AMC files, based loosely on the IPO
 *	interface in blender
 *
 * Copyright (C) 2005 David Trowbridge
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 */

class AMCFrame
{
	System.Collections.Hashtable		data;

	public
	AMCFrame ()
	{
		data = new System.Collections.Hashtable ();
	}

	public void
	AddBone (string[] tokens)
	{
		string name = tokens[0];
		string[] values = new string[tokens.Length - 1];

		System.Array.Copy (tokens, 1, values, 0, values.Length);
		data.Add (name, values);
	}

	public System.Collections.IDictionaryEnumerator
	GetEnumerator ()
	{
		return data.GetEnumerator ();
	}
};

class AMCFile
{
	System.Collections.ArrayList		comments;
	public System.Collections.ArrayList	frames;

	protected
	AMCFile ()
	{
		comments = new System.Collections.ArrayList ();
		frames = new System.Collections.ArrayList ();
	}

	public static AMCFile
	Load (string filename)
	{
		AMCFile f = new AMCFile ();
		AMCFrame frame = null;

		System.IO.StreamReader file = System.IO.File.OpenText (filename);
		if (file == null)
			return null;

		string line;
		while ((line = file.ReadLine ()) != null) {
			// comments
			if (line[0] == '#' || line[0] == ':') {
				f.comments.Add (line);
				continue;
			}

			// are we starting a new frame?
			if (line.IndexOf (' ') == -1) {
				if (frame != null)
					f.frames.Add (frame);
				frame = new AMCFrame ();
				continue;
			}

			string[] tokens = line.Split (' ');
			frame.AddBone (tokens);
		}
		if (frame != null)
			f.frames.Add (frame);

		file.Close ();

		return f;
	}

	public void
	Save (string filename)
	{
		System.IO.StreamWriter file = System.IO.File.CreateText (filename);
		if (file == null)
			return;

		foreach (string line in comments)
			file.Write (System.String.Format ("{0}\n", line));

		file.Close ();
	}
}

class CurveEditor : Gtk.DrawingArea
{
	// Widget data
	Gtk.Adjustment		hadj;
	Gtk.Adjustment		vadj;

	// Drawing data
	Gdk.GC			grey_gc;
	Gdk.GC			black_gc;
	Gdk.Pixmap		back_buffer;

	// Information about the AMC data
	int 			nframes;

	// Window information
	int			width;
	int			height;

	// The AMC file
	AMCFile			amc;
	public AMCFile		AMC
	{
		set
		{
			amc = value;
			nframes = amc.frames.Count;
			CreateBackBuffer ();
			Draw ();

			hadj.Upper = nframes * 40;
			hadj.StepIncrement = 40;

			Gdk.Rectangle r = Allocation;
			r.X = 0; r.Y = 0;
			GdkWindow.InvalidateRect (r, true);
		}
	}

	public
	CurveEditor ()
	{
	}

	void
	CreateGCs ()
	{
		Gdk.Color grey  = new Gdk.Color (0xcc, 0xcc, 0xcc);
		Gdk.Color black = new Gdk.Color (0x00, 0x00, 0x00);

		grey_gc  = new Gdk.GC (GdkWindow);
		black_gc = new Gdk.GC (GdkWindow);

		GdkWindow.Colormap.AllocColor (ref grey,  true, true);
		GdkWindow.Colormap.AllocColor (ref black, true, true);

		grey_gc.Foreground  = grey;
		black_gc.Foreground = black;
	}

	void
	CreateBackBuffer ()
	{
		back_buffer = new Gdk.Pixmap (GdkWindow, Allocation.Width, Allocation.Height);
	}

	void Draw ()
	{
		if (grey_gc == null)
			CreateGCs ();

		Gdk.Rectangle area = Allocation;
		area.X = 0; area.Y = 0;

		// Draw background
		back_buffer.DrawRectangle (grey_gc, true, area);

		if (amc == null)
			return;

		Pango.Layout layout = CreatePangoLayout (null);

		// Draw frame lines and numbers
		for (int i = 0; i < amc.frames.Count; i++) {
			int pos = i * 40 + 20;
			if (pos > hadj.Value && pos < hadj.Value + Allocation.Width) {
				back_buffer.DrawLine (black_gc,
					(int) (pos - hadj.Value), 0,
					(int) (pos - hadj.Value), Allocation.Height - 20);

				layout.SetText (i.ToString ());
				int lw, lh;
				layout.GetPixelSize (out lw, out lh);

				back_buffer.DrawLayout (black_gc, (int) (pos - (lw / 2) - hadj.Value), Allocation.Height - 18, layout);
			}
		}

		// Draw border between frame # and edit region
		back_buffer.DrawLine (black_gc, 0, Allocation.Height - 20, Allocation.Width, Allocation.Height - 20);
	}

	protected override bool
	OnConfigureEvent (Gdk.EventConfigure ev)
	{
		hadj.PageSize = ev.Width;
		hadj.PageIncrement = ev.Width / 2;

		CreateBackBuffer ();
		Draw ();
		return true;
	}

	protected override bool
	OnExposeEvent (Gdk.EventExpose ev)
	{
		GdkWindow.DrawDrawable (grey_gc, back_buffer, ev.Area.X, ev.Area.Y, ev.Area.X, ev.Area.Y, ev.Area.Width, ev.Area.Height);

		return true;
	}

	protected override void
	OnSetScrollAdjustments (Gtk.Adjustment hadj, Gtk.Adjustment vadj)
	{
		this.hadj = hadj;
		this.vadj = vadj;

		hadj.Lower         = 0;
		hadj.Upper         = 1;
		hadj.StepIncrement = 0;
		hadj.PageSize      = 1;
		hadj.PageIncrement = 0;
		hadj.Value         = 0;

		vadj.Lower         = 0;
		vadj.Upper         = 1;
		vadj.StepIncrement = 0;
		vadj.PageSize      = 1;
		vadj.PageIncrement = 0;
		vadj.Value         = 0;

		hadj.ValueChanged += new System.EventHandler (HAdjustmentChanged);
	}

	void
	HAdjustmentChanged (object o, System.EventArgs e)
	{
		Gdk.Rectangle area = Allocation;
		area.X = 0; area.Y = 0;
		Draw ();
		GdkWindow.InvalidateRect (area, true);
	}
}

class CellRendererColor : Gtk.CellRenderer
{
	public override void
	GetSize (Gtk.Widget widget, ref Gdk.Rectangle cell_area, out int x_offset, out int y_offset, out int width, out int height)
	{
		x_offset = 0;
		y_offset = 0;
		width    = 20;
		height   = 20;
	}

	protected override void
	Render (Gdk.Drawable drawable,
		Gtk.Widget widget,
		Gdk.Rectangle background_area,
		Gdk.Rectangle cell_area,
		Gdk.Rectangle expose_area,
		Gtk.CellRendererState flags)
	{
		Gdk.Color color = (Gdk.Color) (GetProperty ("color").Val);
		Gdk.Color border = new Gdk.Color (0x00, 0x00, 0x00);

		Gdk.GC gc = new Gdk.GC (drawable);

		// Draw a 1px black border
		gc.Foreground = border;
		drawable.DrawRectangle (gc, false, cell_area);

		// Draw the color
		gc.Foreground = color;
		cell_area.X      += 1;
		cell_area.Y      += 1;
		cell_area.Width  -= 2;
		cell_area.Height -= 2;
		drawable.DrawRectangle (gc, false, cell_area);
	}
}

class AMCEditor
{
	[Glade.Widget] Gtk.Window		toplevel;
	[Glade.Widget] Gtk.ScrolledWindow	editor_swin;
	[Glade.Widget] Gtk.TreeView		bone_list;
	[Glade.Widget] CurveEditor		curve_editor;

	Gtk.TreeStore				bone_store;
	AMCFile					AMCData;
	string					Filename;

	bool					modified;

	public static void
	Main (string[] args)
	{
		Gtk.Application.Init ();
		new AMCEditor ();
		Gtk.Application.Run ();
	}

	private
	AMCEditor ()
	{
		Glade.XML.SetCustomHandler (new Glade.XMLCustomWidgetHandler (GladeCustomHandler));
		Glade.XML gxml = new Glade.XML (null, "amc-editor.glade", "toplevel", null);
		gxml.Autoconnect (this);

		// Create the tree store
		bone_store = new Gtk.TreeStore (
				typeof (string),	// name
				typeof (Gdk.Color),	// color
				typeof (bool),		// shown on curve window
				typeof (bool));		// whether toggle is visible
		bone_list.Model = bone_store;

		// Create our text column
		Gtk.TreeViewColumn text_column  = new Gtk.TreeViewColumn ();
		Gtk.CellRenderer text_renderer = new Gtk.CellRendererText ();
		text_column.PackStart (text_renderer, true);
		text_column.AddAttribute (text_renderer, "text", 0);
		bone_list.AppendColumn (text_column);

		// Create our color column
		Gtk.TreeViewColumn color_column = new Gtk.TreeViewColumn ();
		Gtk.CellRenderer color_renderer = new CellRendererColor ();
		color_column.PackStart (color_renderer, false);
		color_column.AddAttribute (color_renderer, "color",   1);
		color_column.AddAttribute (color_renderer, "visible", 3);
		//bone_list.AppendColumn (color_column);

		// Create our visible column
		Gtk.TreeViewColumn visible_column = new Gtk.TreeViewColumn ();
		Gtk.CellRendererToggle visible_renderer = new Gtk.CellRendererToggle ();
		visible_column.PackStart (visible_renderer, false);
		visible_column.AddAttribute (visible_renderer, "active", 2);
		visible_column.AddAttribute (visible_renderer, "visible", 3);
		visible_renderer.Activatable = true;
		visible_renderer.Toggled += new Gtk.ToggledHandler (RowToggled);
		bone_list.AppendColumn (visible_column);

		Filename = null;
		modified = false;

		toplevel.ShowAll ();
	}

	void
	RowToggled (object o, Gtk.ToggledArgs args)
	{
		Gtk.TreeIter iter;
		bone_store.GetIter (out iter, new Gtk.TreePath (args.Path));
		bool t = (bool) bone_store.GetValue (iter, 2);
		bone_store.SetValue (iter, 2, !t);
	}

	static Gtk.Widget
	GladeCustomHandler (Glade.XML xml, string func_name, string name, string str1, string str2, int int1, int int2)
	{
		if (func_name == "CurveEditor")
			return new CurveEditor ();
		return null;
	}

	// Signal handlers
	public void
	OnOpen (object o, System.EventArgs args)
	{
		object[] responses = {
			Gtk.Stock.Cancel, Gtk.ResponseType.Reject,
			Gtk.Stock.Open,   Gtk.ResponseType.Accept,
		};
		Gtk.FileChooserDialog fs = new Gtk.FileChooserDialog ("Open AMC...", null, Gtk.FileChooserAction.Open, responses);

		Gtk.ResponseType response = (Gtk.ResponseType) fs.Run ();
		fs.Hide ();

		if (response == Gtk.ResponseType.Accept) {
			Filename = fs.Filename;
			AMCData = AMCFile.Load (Filename);

			bone_store.Clear ();

			if (AMCData == null) {
				// FIXME - pop up an error dialog
				System.Console.WriteLine ("Error loading {0}", Filename);
				Filename = null;
			} else {
				curve_editor.AMC = AMCData;
				SetTitle ();

				AMCFrame f = (AMCFrame) AMCData.frames[0];

				System.Collections.IDictionaryEnumerator e = f.GetEnumerator ();
				e.Reset ();
				while (e.MoveNext ()) {
					Gtk.TreeIter iter;
					iter = bone_store.AppendNode ();
					bone_store.SetValue (iter, 0, e.Key);

					string[] s = (string[]) e.Value;
					for (int i = 0; i < s.Length; i++) {
						Gtk.TreeIter citer = bone_store.AppendNode (iter);
						bone_store.SetValue (citer, 0, i.ToString ());
						bone_store.SetValue (citer, 3, true);
					}
				}
			}
		}
		fs.Destroy ();
	}

	public void
	OnSave (object o, System.EventArgs args)
	{
	}

	public void
	OnSaveAs (object o, System.EventArgs args)
	{
	}

	public void
	OnQuit (object o, System.EventArgs args)
	{
		Gtk.Application.Quit ();
	}

	void
	SetTitle ()
	{
		if (Filename == null) {
			toplevel.Title = "AMC Editor - None";
		} else {
			if (modified)
				toplevel.Title = "AMC Editor - " + System.IO.Path.GetFileName (Filename) + "*";
			else
				toplevel.Title = "AMC Editor - " + System.IO.Path.GetFileName (Filename);
		}
	}
}