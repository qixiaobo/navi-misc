/*
 * navtree.h - functions to create and maintain the navigation tree
 *
 * Copyright (C) 2004 David Trowbridge and Dan Kuester
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

#include <gnome.h>
#include "gui.h"
#include "../common/xchat.h"

#ifndef __XCHAT_GNOME_NAVTREE_H__
#define __XCHAT_GNOME_NAVTREE_H__

G_BEGIN_DECLS

typedef struct _NavTree       NavTree;
typedef struct _NavTreeClass  NavTreeClass;
typedef struct _NavModel      NavModel;
typedef struct _NavModelClass NavModelClass;
/***** NavTree *****/
#define NAVTREE_TYPE            (navigation_tree_get_type ())
#define NAVTREE(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), NAVTREE_TYPE, NavTree))
#define NAVTREE_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), NAVTREE_TYPE, NavTreeClass))
#define IS_NAVTREE(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), NAVTREE_TYPE))
#define IS_NAVTREE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), NAVTREE_TYPE))

struct _NavTree
{
  GtkTreeView parent;
  GtkTreePath *current_path;
  NavModel *model;
};

struct _NavTreeClass
{
  GtkTreeViewClass parent_class;
};

GType navigation_tree_get_type (void) G_GNUC_CONST;
NavTree* navigation_tree_new   (NavModel *model);

/* Add/remove server/channel functions. FIXME: I bet we don't need this,
 * just the ones from the NavModel should be fine. I think the GUI will store
 * a reference to the model independently of the NavTree.
 */
void navigation_tree_create_new_network_entry (NavTree *navtree, struct session *sess);
void navigation_tree_create_new_channel_entry (NavTree *navtree, struct session *sess);
void navigation_tree_remove_channel_entry     (NavTree *navtree, struct session *sess);
void navigation_tree_remove_network_entry     (NavTree *navtree, struct session *sess);

/* Channel/server selection functions. */
void navigation_tree_select_nth_channel  (NavTree *navtree, gint chan_num);
void navigation_tree_select_next_channel (NavTree *navtree);
void navigation_tree_select_prev_channel (NavTree *navtree);
void navigation_tree_select_next_network (NavTree *navtree);
void navigation_tree_select_prev_network (NavTree *navtree);

/* Misc. functions. */
void navigation_tree_set_channel_name (NavTree *navtree, struct session *sess);
void navigation_tree_set_disconn      (NavTree *navtree, struct session *sess);
void navigation_tree_set_hilight      (NavTree *navtree, struct session *sess);

/***** NavModel *****/
#define NAVMODEL_TYPE            (navigation_model_get_type ())
#define NAVMODEL(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), NAVMODEL_TYPE, NavModel))
#define NAVMODEL_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), NAVMODEL_TYPE, NavModelClass))
#define IS_NAVMODEL(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), NAVMODEL_TYPE))
#define IS_NAVMODEL_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), NAVMODEL_TYPE))

struct _NavModel
{
  GObject parent;
  GtkTreeModel *sorted;
  GtkTreeStore *store;
};

struct _NavModelClass
{
  GObjectClass parent;
};

GType navigation_model_get_type (void) G_GNUC_CONST;
NavModel* navigation_model_new  (void);

/* Add/remove server/channel functions. */
void navigation_model_add_new_network (NavModel *model, struct session *sess);
void navigation_model_add_new_channel (NavModel *model, struct session *sess);
void navigation_model_remove          (NavModel *model, struct session *sess);

G_END_DECLS

#endif
