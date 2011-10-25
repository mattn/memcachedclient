#ifdef _WIN32
# include <windows.h>
#endif
#include <gtk/gtk.h>
#include <gdk/gdkkeysyms.h>
#include <libmemcached/memcached.h>
#include <stdio.h>

// clone of http://code.sixapart.com/svn/memcached/trunk/frontends/gtk2-perl/

static void display(const gchar* level, const gchar* text, GtkWidget* toplevel) {
	GtkTextBuffer* buffer;
	GtkTextIter iter;
	gchar* out_text = g_strdup_printf("%s\n", text);

	buffer = (GtkTextBuffer*) g_object_get_data(G_OBJECT(toplevel), "buffer");
	gtk_text_buffer_get_end_iter(buffer, &iter);
	gtk_text_buffer_insert_with_tags_by_name(buffer, &iter, out_text, -1, level, NULL);
	g_free(out_text);
}

static void run_command(const gchar* text, GtkWidget* toplevel) {
	memcached_st *memc;
	GArray* cmds;
	int* cmd_cur_ptr;
	GtkWidget* entry;
	const gchar* cmd_ptr = NULL;
	gchar* key_ptr = NULL;
	gchar* val_ptr = NULL;
	memcached_return rc;

	memc = (memcached_st*) g_object_get_data(G_OBJECT(toplevel), "mc");
	cmds = (GArray*) g_object_get_data(G_OBJECT(toplevel), "cmds");
	cmd_cur_ptr = (int*) g_object_get_data(G_OBJECT(toplevel), "cmd_cur");
	entry = (GtkWidget*) g_object_get_data(G_OBJECT(toplevel), "entry");

	if (*cmd_cur_ptr >= 0 && g_array_index(cmds, gchar*, *cmd_cur_ptr)) {
		g_array_remove_index(cmds, 0);
	}

	text = g_strdup(text);
	g_array_append_val(cmds, text);

	display("command", text, toplevel);

	cmd_ptr = g_strdup(text);

	key_ptr = g_strstr_len(cmd_ptr, strlen(cmd_ptr), " ");
	if (key_ptr) {
		*key_ptr++ = 0;
		val_ptr = g_strstr_len(key_ptr, strlen(key_ptr), " ");
		if (val_ptr) *val_ptr++ = 0;
	}

	if (!g_strcasecmp(cmd_ptr, "get") && key_ptr) {
		int value_length = 0;
		int flags = 0;
		val_ptr = memcached_get(memc, key_ptr, strlen(key_ptr), &value_length, &flags, &rc);
		if (val_ptr)
			display("data", val_ptr, toplevel);
		else {
			display("error", "Not found.", toplevel);
			g_fprintf(stderr, "memcached_get(%s)\n", memcached_strerror(memc, rc));
		}
	}
	else
	if (!g_strcasecmp(cmd_ptr, "set") && key_ptr && val_ptr) {
		rc = memcached_set(memc, key_ptr, strlen(key_ptr), val_ptr, strlen(val_ptr), 0, 0);
		if (rc == MEMCACHED_SUCCESS)
			display("data", "Ok.", toplevel);
		else {
			display("error", "Not found.", toplevel);
			g_fprintf(stderr, "memcached_set(%s)\n", memcached_strerror(memc, rc));
		}
	}
	else
	if (!g_strcasecmp(cmd_ptr, "delete") && key_ptr) {
		rc = memcached_delete(memc, key_ptr, strlen(key_ptr), 0);
		if (rc == MEMCACHED_SUCCESS)
			display("data", "Ok.", toplevel);
		else {
			display("error", "Not found.", toplevel);
			g_fprintf(stderr, "memcached_delete(%s)\n", memcached_strerror(memc, rc));
		}
	} else {
		gchar* out_text = g_strdup_printf("Unknown command '%s'.", text);
		display("error", out_text, toplevel);
		g_free((gpointer) out_text);
	}


	g_free((gpointer) cmd_ptr);
}

static gboolean entry_keypress(GtkWidget* entry, GdkEvent* ev) {
	GArray* cmds;
	int* cmd_cur_ptr;
	GtkWidget* toplevel;
	gchar* text;

	toplevel = gtk_widget_get_toplevel(entry);
	cmds = (GArray*) g_object_get_data(G_OBJECT(toplevel), "cmds");
	cmd_cur_ptr = (int*) g_object_get_data(G_OBJECT(toplevel), "cmd_cur");

	if (ev->key.keyval == GDK_Up) {
		if (*cmd_cur_ptr < (int)(cmds->len - 1)) (*cmd_cur_ptr)++;
		text = g_array_index(cmds, gchar*, *cmd_cur_ptr);
		if (text) gtk_entry_set_text(GTK_ENTRY(entry), text);
		return TRUE;
	} else
	if (ev->key.keyval == GDK_Down) {
		if (*cmd_cur_ptr >= 0) (*cmd_cur_ptr)--;
		text = g_array_index(cmds, gchar*, *cmd_cur_ptr);
		if (*cmd_cur_ptr >= 0 && text) gtk_entry_set_text(GTK_ENTRY(entry), text);
		return TRUE;
	}
	return FALSE;
}

static void entry_activate(GtkWidget* widget, gpointer user_data) {
	const gchar* text = gtk_entry_get_text(GTK_ENTRY(widget));
	if (strlen(text)) {
		run_command(text, gtk_widget_get_toplevel(widget));
		gtk_entry_set_text(GTK_ENTRY(widget), "");
	}
}

static void window_show(GtkWidget* widget, gpointer user_data) {
	gtk_widget_grab_focus((GtkWidget*) user_data);
}

int main(int argc, char* argv[]) {
	GtkWidget* win;
	GtkWidget* vb;
	GtkWidget* textview;
	GtkTextBuffer* buffer;
	GtkWidget* scroll;
	PangoFontDescription* font;
	GtkWidget* entry;
	memcached_return rc;
	memcached_st *memc;
	GArray* cmds = NULL;
	int cmd_cur = -1;

	cmds = g_array_new(TRUE, TRUE, sizeof(gchar*));
	memc = memcached_create(NULL);
	rc = memcached_server_add(memc, "127.0.0.1", 11211);
	if (rc != MEMCACHED_SUCCESS) {
		g_fprintf(stderr, "memcached_server_add(%s)\n", memcached_strerror(memc, rc));
	}

	gtk_init(&argc, &argv);

	win = gtk_window_new(GTK_WINDOW_TOPLEVEL);
	g_signal_connect(G_OBJECT(win), "delete-event", gtk_main_quit, win);
	gtk_container_set_border_width(GTK_CONTAINER(win), 10);

	vb = gtk_vbox_new(FALSE, 5);
	textview = gtk_text_view_new();
	buffer = gtk_text_view_get_buffer(GTK_TEXT_VIEW(textview));
	gtk_text_view_set_editable(GTK_TEXT_VIEW(textview), FALSE);

	scroll = gtk_scrolled_window_new(NULL, NULL);
	gtk_scrolled_window_set_policy(
			GTK_SCROLLED_WINDOW(scroll),
			GTK_POLICY_AUTOMATIC, 
			GTK_POLICY_AUTOMATIC);
	gtk_scrolled_window_set_shadow_type(
			GTK_SCROLLED_WINDOW(scroll),
			GTK_SHADOW_IN
	);
	gtk_container_add(GTK_CONTAINER(scroll), textview);
	gtk_box_pack_start(GTK_BOX(vb), scroll, TRUE, TRUE, 0);

	font = pango_font_description_new();
	pango_font_description_set_family(font, "monospace");
	gtk_widget_modify_font(textview, font);
	pango_font_description_free(font);

	gtk_text_buffer_create_tag(buffer, "command", "foreground", "blue", NULL);
	gtk_text_buffer_create_tag(buffer, "data", "foreground", "black", NULL);
	gtk_text_buffer_create_tag(buffer, "error", "foreground", "red", NULL);

	entry = gtk_entry_new();
	g_signal_connect(G_OBJECT(entry), "key-press-event", G_CALLBACK(entry_keypress), entry);
	g_signal_connect(G_OBJECT(entry), "activate", G_CALLBACK(entry_activate), entry);
	gtk_box_pack_start(GTK_BOX(vb), entry, FALSE, FALSE, 0);

	gtk_container_add(GTK_CONTAINER(win), vb);

	gtk_window_set_title(GTK_WINDOW(win), "MemCachedClient");
	gtk_window_set_default_size(GTK_WINDOW(win), 400, 500);
	g_signal_connect(G_OBJECT(win), "show", G_CALLBACK(window_show), entry);
	gtk_widget_show_all(GTK_WIDGET(win));

	g_object_set_data(G_OBJECT(win), "mc", (gpointer) memc);
	g_object_set_data(G_OBJECT(win), "cmds", (gpointer) cmds);
	g_object_set_data(G_OBJECT(win), "cmd_cur", (gpointer) &cmd_cur);
	g_object_set_data(G_OBJECT(win), "entry", (gpointer) entry);
	g_object_set_data(G_OBJECT(win), "buffer", (gpointer) buffer);

	gtk_main();

	g_array_free(cmds, TRUE);

	return 0;
}

#ifdef _WIN32
int WINAPI WinMain(HINSTANCE hCurInst, HINSTANCE hPrevInst, LPSTR lpsCmdLine, int nCmdShow)
{
	return main(__argc, __argv);
}
#endif
