INCLUDES = 								\
	-DG_LOG_DOMAIN=\"calendar-gui\"					\
	-I$(top_srcdir)							\
	-I$(top_builddir)						\
	-I$(top_srcdir)/calendar					\
	-I$(top_srcdir)/calendar/cal-client				\
	-I$(top_builddir)/calendar/cal-client				\
	-I$(top_builddir)/shell						\
	-I$(top_srcdir)/shell						\
	-I$(top_srcdir)/widgets/misc					\
	-DEVOLUTION_DATADIR=\""$(datadir)"\"				\
	-DEVOLUTION_GLADEDIR=\""$(gladedir)"\"				\
	-DEVOLUTION_IMAGESDIR=\""$(imagesdir)"\"			\
	-DEVOLUTION_UIDIR=\""$(evolutionuidir)"\"			\
	-DPREFIX=\""$(prefix)"\"					\
	$(EVOLUTION_CALENDAR_CFLAGS)

noinst_LTLIBRARIES = libcal-dialogs.la

libcal_dialogs_la_LIBADD =					\
	$(top_builddir)/addressbook/util/libeabutil.la

libcal_dialogs_la_SOURCES =	\
	$(IDL_GENERATED)	\
	alarm-dialog.c		\
	alarm-dialog.h		\
	alarm-list-dialog.c	\
	alarm-list-dialog.h	\
	cal-attachment-bar.c    \
	cal-attachment-bar.h    \
	cal-attachment-select-file.c \
	cal-attachment-select-file.h \
	cal-attachment.c        \
	cal-attachment.h        \
	cal-prefs-dialog.c	\
	cal-prefs-dialog.h	\
	calendar-setup.c	\
	calendar-setup.h	\
	cancel-comp.c		\
	cancel-comp.h		\
	changed-comp.c		\
	changed-comp.h		\
	comp-editor.c		\
	comp-editor.h		\
	comp-editor-page.c	\
	comp-editor-page.h	\
	comp-editor-util.c	\
	comp-editor-util.h	\
	copy-source-dialog.c	\
	copy-source-dialog.h	\
	delete-comp.c		\
	delete-comp.h		\
	delete-error.c		\
	delete-error.h		\
	e-delegate-dialog.c	\
	e-delegate-dialog.h	\
	e-send-options-utils.c  \
	e-send-options-utils.h  \
	event-editor.c		\
	event-editor.h		\
	event-page.c		\
	event-page.h		\
	meeting-page.c		\
	meeting-page.h		\
	recurrence-page.c	\
	recurrence-page.h	\
	recur-comp.c		\
	recur-comp.h		\
	save-comp.c		\
	save-comp.h		\
	schedule-page.c		\
	schedule-page.h		\
	select-source-dialog.c	\
	select-source-dialog.h	\
	send-comp.c		\
	send-comp.h		\
	task-editor.c		\
	task-editor.h		\
	task-details-page.c	\
	task-details-page.h	\
	task-page.c		\
	task-page.h

glade_DATA =				\
	alarm-dialog.glade		\
	alarm-list-dialog.glade		\
	cal-attachment.glade            \
	cal-prefs-dialog.glade		\
	e-delegate-dialog.glade		\
	event-page.glade		\
	meeting-page.glade		\
	recurrence-page.glade		\
	schedule-page.glade		\
	task-details-page.glade		\
	task-page.glade			\
	url-editor-dialog.glade

CLEANFILES = $(BUILT_SOURCES)

dist-hook:
	cd $(distdir); rm -f $(BUILT_SOURCES)

EXTRA_DIST =			\
	$(glade_DATA)
