/*
 * HistogramImager.cs - An Element which implements the histogram
 *	imager algorithm.
 *
 * Fyre - a generic framework for computational art
 * Copyright (C) 2004-2005 Fyre Team (see AUTHORS)
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

using System.Xml;

class Pixmap : Fyre.Element
{
	static Gdk.Pixbuf icon;

	public
	Pixmap ()
	{
		inputs = new Fyre.InputPad[4];
		inputs[0] = new Fyre.InputPad ("w", "width", "int");
		inputs[1] = new Fyre.InputPad ("h", "height", "int");
		inputs[2] = new Fyre.InputPad ("v", "point", "pair(int)");
		inputs[3] = new Fyre.InputPad ("c", "color", "color");

		outputs = new Fyre.OutputPad[1];
		outputs[0] = new Fyre.OutputPad ("M", "image", "image");

		NewCanvasElement ();
		NewID ();
	}

	public override string
	Name ()
	{
		return "Pixmap";
	}

	public override string
	Category()
	{
		return "Renderers";
	}

	public override Gdk.Pixbuf
	Icon ()
	{
		if (icon == null)
			icon = new Gdk.Pixbuf (null, "Pixmap.png");
		return icon;
	}

	public override string
	Description ()
	{
		return "Simple pixmap image";
	}

	public override string[,]
	InputDesc ()
	{
		string [,]desc = new string[4,2];

		for (int i = 0; i < 4; i++) {
			desc[i,0] = "<i>" + inputs[i].Name + "</i>";
			desc[i,1] = inputs[i].Description;
		}

		return desc;
	}

	public override string[,]
	OutputDesc ()
	{
		string [,]desc = new string[1,2];

		desc[0,0] = "<b>" + outputs[0].Name + "</b>";
		desc[0,1] = outputs[0].Description;

		return desc;
	}

	public override void
	Serialize (XmlWriter writer)
	{
		base.Serialize (writer);
	}

	public override void
	DeSerialize (XmlReader reader)
	{
		base.DeSerialize (reader);
	}
}