import threading
import tomllib
import gi
gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, Gdk, Gio, GLib
from .common import HOME


def label(text, css=None):
    obj = Gtk.Label(label=text, xalign=0)
    obj.set_wrap(True)
    if css:
        obj.add_css_class(css)
    return obj


def box(vertical=True, spacing=12):
    return Gtk.Box(orientation=Gtk.Orientation.VERTICAL if vertical else Gtk.Orientation.HORIZONTAL, spacing=spacing)


def button(text, callback, css=None):
    obj = Gtk.Button(label=text)
    obj.connect('clicked', lambda _: callback())
    if css:
        obj.add_css_class(css)
    return obj


def clear(container):
    while container.get_first_child():
        container.remove(container.get_first_child())


def scroll(child):
    obj = Gtk.ScrolledWindow()
    obj.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
    obj.set_vexpand(True)
    obj.set_child(child)
    return obj


def textview(editable=True):
    obj = Gtk.TextView(editable=editable, monospace=True, wrap_mode=Gtk.WrapMode.WORD_CHAR)
    obj.set_top_margin(12); obj.set_bottom_margin(12)
    obj.set_left_margin(12); obj.set_right_margin(12)
    return obj


def text(obj):
    b = obj.get_buffer()
    return b.get_text(b.get_start_iter(), b.get_end_iter(), True)


class Page(Gtk.Box):
    def __init__(self, window, title, subtitle):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.window = window
        for side in ('top', 'bottom', 'start', 'end'):
            getattr(self, 'set_margin_' + side)(24)
        self.append(label(title, 'title'))
        self.append(label(subtitle, 'muted'))

    def status(self, message):
        self.window.status.set_text(str(message))

    def work(self, fn, done=None):
        self.set_sensitive(False)
        self.status('처리 중…')
        def worker():
            try:
                result = fn()
                def success():
                    self.set_sensitive(True)
                    if done:
                        done(result)
                    else:
                        self.status(str(result))
                    return False
                GLib.idle_add(success)
            except Exception as error:
                message = str(error)
                GLib.idle_add(lambda: (self.set_sensitive(True), self.status('오류: ' + message), False)[2])
        threading.Thread(target=worker, daemon=True).start()


def theme():
    colors = dict(background='#111923', foreground='#cad6e5', accent='#79d5c8', lighter_background='#1b2938')
    path = HOME / '.local/state/omarchy/current/theme/colors.toml'
    if path.exists():
        colors.update(tomllib.loads(path.read_text()))
    provider = Gtk.CssProvider()
    css = '''
    window, .background { background: BG; color: FG; }
    .title { font-size: 26px; font-weight: 800; }
    .muted { opacity: 0.7; }
    .accent { color: ACC; }
    .card { background: SUR; border-radius: 12px; padding: 16px; }
    button { border-radius: 9px; padding: 8px 12px; }
    button.suggested-action { background: ACC; color: BG; }
    entry, textview, textview text { background: SUR; color: FG; }
    entry { padding: 8px; border-radius: 8px; }
    .sidebar { background: SUR; padding: 12px; }
    .status { padding: 10px 20px; font-size: 12px; }
    '''.replace('BG', colors['background']).replace('FG', colors['foreground']).replace('ACC', colors['accent']).replace('SUR', colors['lighter_background'])
    provider.load_from_string(css)
    Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
    settings = Gtk.Settings.get_default()
    settings.set_property('gtk-application-prefer-dark-theme', True)
