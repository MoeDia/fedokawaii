/* filechooser.c — GTK 3's "Open File" dialog, as xdg-desktop-portal-gtk shows it to an app
 * that asks the FileChooser portal (Brave's "Upload", "Open file…"): a GtkFileChooserDialog
 * in OPEN mode with Cancel / Open, in the folder it is given. The theme is whatever GTK
 * picks from GSettings (gtk-theme): no GTK_THEME, no CSS of its own. Built by apps.sh
 * against /opt/f44's GTK 3.24.52.
 *
 *   kawa-filechooser [FOLDER]      prints the chosen path, or nothing on Cancel / Escape
 */
#include <gtk/gtk.h>

int main(int argc, char **argv)
{
	g_set_prgname("kawa-filechooser");      /* the Wayland app_id the compositor sees */
	gtk_init(&argc, &argv);
	GtkWidget *d = gtk_file_chooser_dialog_new("Open File", NULL, GTK_FILE_CHOOSER_ACTION_OPEN,
	                                           "_Cancel", GTK_RESPONSE_CANCEL,
	                                           "_Open", GTK_RESPONSE_ACCEPT, NULL);
	gtk_dialog_set_default_response(GTK_DIALOG(d), GTK_RESPONSE_ACCEPT);
	gtk_file_chooser_set_local_only(GTK_FILE_CHOOSER(d), FALSE);
	gtk_file_chooser_set_current_folder(GTK_FILE_CHOOSER(d), argc > 1 ? argv[1] : g_get_home_dir());
	GtkSettings *s = gtk_settings_get_default();
	gchar *theme = NULL, *icons = NULL;
	gboolean dark = FALSE;
	g_object_get(s, "gtk-theme-name", &theme, "gtk-icon-theme-name", &icons,
	             "gtk-application-prefer-dark-theme", &dark, NULL);
	g_printerr("kawa-filechooser: gtk %u.%u.%u, theme %s, icons %s\n", gtk_get_major_version(),
	           gtk_get_minor_version(), gtk_get_micro_version(), theme, icons);
	g_free(theme);
	g_free(icons);
	if (gtk_dialog_run(GTK_DIALOG(d)) == GTK_RESPONSE_ACCEPT) {
		gchar *f = gtk_file_chooser_get_filename(GTK_FILE_CHOOSER(d));
		g_print("%s\n", f ? f : "");
		g_free(f);
	}
	gtk_widget_destroy(d);
	return 0;
}
