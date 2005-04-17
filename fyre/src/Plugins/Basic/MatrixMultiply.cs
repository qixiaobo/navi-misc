/*
 * MatrixMultply.cs - An Element which takes a vector and a matrix
 *	and multiplies the two.
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

class MatrixMultiply : Fyre.Element
{
	static Gdk.Pixbuf icon;

	public
	MatrixMultiply () : base ()
	{
		inputs = new Fyre.InputPad[] {
			new Fyre.InputPad ("v<sub>0</sub>", "point"),
			new Fyre.InputPad ("M", "matrix"),
		};

		outputs = new Fyre.OutputPad[] {
			new Fyre.OutputPad ("v<sub>1</sub>", "new point"),
		};

		SetPadNumbers ();
		NewID ();
	}

	public override string
	Name ()
	{
		return "Matrix Multiply";
	}

	public override string
	Category()
	{
		return "Arithmetic";
	}

	public override Gdk.Pixbuf
	Icon ()
	{
		if (icon == null)
			icon = new Gdk.Pixbuf (null, "MatrixMultiply.png");
		return icon;
	}

	public override string
	Description ()
	{
		return "Multiplies a vector\nand a matrix";
	}

	public override bool
	Check (Fyre.Type[] t, out Fyre.Type[] to)
	{
		to = null;

		// Check that pad 1 is a rank 1 matrix
		if (!((Fyre.Type.IsMatrix (t[0])) &&
		      (Fyre.Type.GetMatrixRank (t[0]) == 1)))
			return false;
		Fyre.Type mt1 = Fyre.Type.GetMatrixType (t[0]);

		// Check that pad 2 is a rank 2 matrix
		if (!((Fyre.Type.IsMatrix (t[1])) &&
		      (Fyre.Type.GetMatrixRank (t[0]) == 2)))
			return false;
		Fyre.Type mt2 = Fyre.Type.GetMatrixType (t[1]);

		// Make sure that the types match and we're either int or float
		bool oktype = false;
		if (Fyre.Type.IsInt (mt1) && Fyre.Type.IsInt (mt2))
			oktype = true;
		if (Fyre.Type.IsFloat (mt1) && Fyre.Type.IsFloat (mt2))
			oktype = true;
		if (!oktype)
			return false;

		int size1 = Fyre.Type.GetMatrixSize (t[0])[0];
		int size2 = Fyre.Type.GetMatrixSize (t[1])[1];

		if (size1 != size2)
			return false;

		to = new Fyre.Type[] {
			t[0],
		};

		return true;
	}
}
