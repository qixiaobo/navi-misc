/*
 * PluginManager.cs - abstract data type defining an Element
 *
 * Fyre - rendering and interactive exploration of chaotic functions
 * Copyright (C) 2004-2005 David Trowbridge and Micah Dowty
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

using System;
using System.Collections;
using System.IO;
using System.Reflection;

namespace Fyre {

	class PluginManager
	{
		string directory;
		public ArrayList plugin_types;

		public
		PluginManager (string directory)
		{
			this.directory = directory;

			plugin_types = FindPluginTypes ();
		}

		ArrayList
		FindPluginTypes ()
		{
			ArrayList all_plugin_types = new ArrayList ();

			ArrayList files = new ArrayList();
			string current_dir = Directory.GetCurrentDirectory();

			if (current_dir.IndexOf (Defines.DATADIR) == -1) {
				// Before make install is run, the plugins are in the Plugins/<plugin name>
				// directory. So we go through each dir in the Plugins/ dir and look
				// for dll's. The nested for loops are a bit gross, but it's not likely
				// that there's a huge amount of stuff in these directory.

				string plugins = String.Concat (current_dir, "/Plugins"),			// ./Plugins
					   src_plugins = String.Concat (current_dir, "/src/Plugins");	// ./src/Plugins

				if (Directory.Exists (plugins)) {
					foreach (string dir in Directory.GetDirectories (plugins)) {
						foreach (string file in Directory.GetFiles (dir, "*.dll"))
							files.Add (file);
					}
				}

				if (Directory.Exists (src_plugins)) {
					foreach (string dir in Directory.GetDirectories (src_plugins)) {
						foreach (string file in Directory.GetFiles (dir, "*.dll"))
							files.Add (file);
					}
				}
			}

			// Add all the files in the PLUGINSDIR to the list of plugins.
			if (Directory.Exists (directory))
				foreach (string file in Directory.GetFiles (directory, "*.dll")) {
					if (!files.Contains (file))
						files.Add (file);
				}

			// Pull in types from assemblies
			foreach (string file in files) {
				try {
					ArrayList asm_types = FindPluginTypesInFile (file);
					foreach (Type type in asm_types)
						all_plugin_types.Add (type);
				} catch (Exception e) {
					Console.WriteLine ("Error loading plugin: {0}", e);
				}
			}

			return all_plugin_types;
		}

		static ArrayList
		FindPluginTypesInFile (string filepath)
		{
			Assembly asm = Assembly.LoadFrom (filepath);
			return FindPluginTypesInAssembly (asm);
		}

		static ArrayList
		FindPluginTypesInAssembly (Assembly asm)
		{
			Type [] types = asm.GetTypes ();
			ArrayList plugin_types = new ArrayList ();

			// Grab Element types. Eventually, we might want to convert this
			// to just load everything and keep a hash for different plugin hooks
			foreach (Type type in types)
				if (type.BaseType == typeof (Element))
					plugin_types.Add (type);

			return plugin_types;
		}
	}

}
