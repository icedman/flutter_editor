bool handle_keybinding(struct tinywl_server* server,
    xkb_keysym_t sym)
{
    switch (sym) {
    case XKB_KEY_Escape:
        wl_display_terminate(server->wl_display);
        break;
    case XKB_KEY_F1:

        if (wl_list_length(&server->views) < 2) {
            break;
        }
        struct tinywl_view* current_view = wl_container_of(server->views.next, current_view, link);
        struct tinywl_view* next_view = wl_container_of(current_view->link.next, next_view, link);
        focus_view(next_view, next_view->xdg_surface->surface);
        wl_list_remove(&current_view->link);
        wl_list_insert(server->views.prev, &current_view->link);
        break;
    default:
        return false;
    }
    return true;
}


