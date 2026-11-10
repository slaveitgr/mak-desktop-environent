// makOS bridge to the pinned Cutefish protocols. Qt owns this Wayland connection.
#include <QGuiApplication>
#include <QWindow>
#include <QPointer>
#include <QPlatformSurfaceEvent>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QQmlExtensionPlugin>
#include <qqml.h>
#include <QtGui/qpa/qplatformnativeinterface.h>
#include <QWaylandClientExtension>
#include <wayland-client.h>
#include <functional>
#include <memory>
#include <vector>
#include "qwayland-cutefish-main-menu-v1.h"
#include "qwayland-cutefish-surface-blur-v1.h"
#include "qwayland-cutefish-window-hints-v1.h"

class Menus : public QWaylandClientExtensionTemplate<Menus>, public QtWayland::cutefish_main_menu_manager_v1 {
public:
    Menus() : QWaylandClientExtensionTemplate(1) {}
    ~Menus() { if (isActive()) destroy(); }
};
class Glass : public QWaylandClientExtensionTemplate<Glass>, public QtWayland::cutefish_surface_blur_v1 {
public:
    Glass() : QWaylandClientExtensionTemplate(1) {}
    ~Glass() { if (isActive()) destroy(); }
};
class Hints : public QWaylandClientExtensionTemplate<Hints>, public QtWayland::cutefish_window_hints_v1 {
public:
    Hints() : QWaylandClientExtensionTemplate(1) {}
    ~Hints() { if (isActive()) destroy(); }
    std::function<void(wl_surface *, int, uint32_t)> reveal;
    void cutefish_window_hints_v1_fullscreen_reveal(wl_surface *s, int32_t offset, uint32_t duration) override {
        if (reveal) reveal(s, offset, duration);
    }
};

struct MenuNode;
struct MenuItem : QtWayland::cutefish_menu_item_v1 {
    explicit MenuItem(::cutefish_menu_item_v1 *p) : QtWayland::cutefish_menu_item_v1(p) {}
    ~MenuItem() override;
    QString command;
    int kind = 0;
    std::function<void(QString)> dispatch;
    std::unique_ptr<MenuNode> submenu;
    void cutefish_menu_item_v1_activated(uint32_t) override { if (dispatch && !command.isEmpty()) dispatch(command); }
};
struct MenuNode : QtWayland::cutefish_menu_v1 {
    MenuNode(Menus *m, std::function<void(QString)> action, std::function<void()> refresh)
        : QtWayland::cutefish_menu_v1(m->create_menu()), manager(m), dispatch(action), refresh(refresh) {}
    ~MenuNode() override { items.clear(); destroy(); }
    Menus *manager;
    std::function<void(QString)> dispatch;
    std::function<void()> refresh;
    std::vector<std::unique_ptr<MenuItem>> items;
    void cutefish_menu_v1_will_open(uint32_t serial) override {
        // Refresh in place: never destroy the menu answering this serial.
        if (refresh) refresh();
        ready(serial);
    }
    void update(const QJsonArray &rows) {
        while (items.size() > size_t(rows.size())) items.pop_back();
        for (int i = 0; i < rows.size(); ++i) {
            const auto row = rows[i].toObject();
            const int kind = row.value("separator").toBool() ? 1 : 0;
            if (size_t(i) < items.size() && items[i]->kind != kind) {
                remove_item(items[i]->object());
                items.erase(items.begin() + i);
            }
            if (size_t(i) >= items.size() || items[i]->kind != kind) {
                auto item = std::make_unique<MenuItem>(manager->create_item(kind));
                item->kind = kind; item->dispatch = dispatch;
                insert_item(item->object(), i);
                items.insert(items.begin() + i, std::move(item));
            }
            auto &item = items[i];
            item->command = row.value("command").toString();
            item->set_title(row.value("label").toString());
            item->set_enabled(row.value("enabled").toBool(true));
            item->set_hidden(row.value("hidden").toBool(false));
            item->set_state(row.value("checked").toBool() ? 1 : 0);
            item->set_icon_name(row.value("icon").toString());
            QString key = row.value("shortcut").toString();
            uint32_t mods = 0;
            for (const auto &pair : {qMakePair(QStringLiteral("⇧"),1u), qMakePair(QStringLiteral("Shift+"),1u),
                 qMakePair(QStringLiteral("⌃"),2u), qMakePair(QStringLiteral("Ctrl+"),2u),
                 qMakePair(QStringLiteral("⌥"),4u), qMakePair(QStringLiteral("Alt+"),4u),
                 qMakePair(QStringLiteral("⌘"),2u)}) {
                if (key.contains(pair.first)) { mods |= pair.second; key.remove(pair.first); }
            }
            if (key == QStringLiteral("⌫")) key = QStringLiteral("BackSpace");
            if (key == QStringLiteral("⎋")) key = QStringLiteral("Escape");
            if (key == QStringLiteral("Space")) key = QStringLiteral("space");
            item->set_key_equivalent(key, mods);
            if (row.contains("submenu")) {
                if (!item->submenu) {
                    item->submenu = std::make_unique<MenuNode>(manager, dispatch, refresh);
                    item->set_submenu(item->submenu->object());
                }
                item->submenu->set_role(row.value("role").toInt());
                item->submenu->update(row.value("submenu").toArray());
            } else if (item->submenu) {
                item->set_submenu(nullptr); item->submenu.reset();
            }
        }
    }
};

MenuItem::~MenuItem() { submenu.reset(); destroy(); }

class CutefishWindow : public QObject {
    Q_OBJECT
    Q_PROPERTY(QWindow *window READ window WRITE setWindow NOTIFY changed)
    Q_PROPERTY(QString menus READ menus WRITE setMenus NOTIFY changed)
    Q_PROPERTY(QRect glassRect READ glassRect WRITE setGlassRect NOTIFY changed)
    Q_PROPERTY(bool glassEnabled READ glassEnabled WRITE setGlassEnabled NOTIFY changed)
    Q_PROPERTY(bool dark READ dark WRITE setDark NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(int revealOffset READ revealOffset NOTIFY revealChanged)
    Q_PROPERTY(int revealDuration READ revealDuration NOTIFY revealChanged)
public:
    explicit CutefishWindow(QObject *parent = nullptr) : QObject(parent) {
        for (auto extension : {static_cast<QWaylandClientExtension *>(&m_menus), static_cast<QWaylandClientExtension *>(&m_glass), static_cast<QWaylandClientExtension *>(&m_hints)})
            connect(extension, &QWaylandClientExtension::activeChanged, this, [this] { schedule(); });
        m_hints.reveal = [this](wl_surface *s, int offset, uint32_t duration) {
            if (s == surface()) { m_offset = offset; m_duration = int(duration); emit revealChanged(); }
        };
    }
    ~CutefishWindow() override { m_tree.reset(); if (m_window) m_window->removeEventFilter(this); }
    QWindow *window() const { return m_window; }
    QString menus() const { return m_json; }
    QRect glassRect() const { return m_rect; }
    bool glassEnabled() const { return m_enabled; }
    bool dark() const { return m_dark; }
    bool active() const { return m_bound && m_menus.isActive() && m_glass.isActive() && m_hints.isActive(); }
    int revealOffset() const { return m_offset; }
    int revealDuration() const { return m_duration; }
    void setWindow(QWindow *value) {
        if (m_window == value) return;
        if (m_window) m_window->removeEventFilter(this);
        m_window = value; m_bound = nullptr;
        if (value) {
            value->installEventFilter(this);
            connect(value, &QWindow::widthChanged, this, [this] { schedule(); });
            connect(value, &QWindow::heightChanged, this, [this] { schedule(); });
        }
        schedule(); emit changed();
    }
    void setMenus(const QString &v) { if (v != m_json) { m_json = v; updateMenus(); emit changed(); } }
    void setGlassRect(const QRect &v) { if (v != m_rect) { m_rect = v; schedule(); emit changed(); } }
    void setGlassEnabled(bool v) { if (v != m_enabled) { m_enabled = v; schedule(); emit changed(); } }
    void setDark(bool v) { if (v != m_dark) { m_dark = v; schedule(); emit changed(); } }
signals:
    void changed();
    void revealChanged();
    void commandTriggered(QString command);
    void refreshRequested();
protected:
    bool eventFilter(QObject *, QEvent *e) override {
        if (e->type() == QEvent::PlatformSurface && static_cast<QPlatformSurfaceEvent *>(e)->surfaceEventType() == QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed) {
            m_bound = nullptr; emit changed();
        } else if (e->type() == QEvent::Expose || e->type() == QEvent::Show) schedule();
        return false;
    }
private:
    wl_surface *surface() const {
        if (!m_window || !m_window->handle() || QGuiApplication::platformName() != "wayland") return nullptr;
        return static_cast<wl_surface *>(QGuiApplication::platformNativeInterface()->nativeResourceForWindow("surface", m_window));
    }
    void schedule() {
        if (m_scheduled) return;
        m_scheduled = true;
        QTimer::singleShot(0, this, [this] { m_scheduled = false; apply(); });
    }
    void updateMenus() {
        if (!m_tree) return;
        auto document = QJsonDocument::fromJson(m_json.toUtf8());
        if (document.isArray()) m_tree->update(document.array());
    }
    void apply() {
        auto s = surface();
        if (!s || !m_window->isExposed() || !m_menus.isActive() || !m_glass.isActive() || !m_hints.isActive()) return;
        if (!m_tree) {
            m_tree = std::make_unique<MenuNode>(&m_menus, [this](QString command) { emit commandTriggered(command); }, [this] { emit refreshRequested(); });
            updateMenus();
        }
        if (m_bound != s) {
            m_menus.set_main_menu(s, m_tree->object());
            m_hints.set_server_resize(s, 1);
            m_hints.set_fullscreen_bars(s, 50, 0);
            m_bound = s;
            qInfo("MAKOS_CUTEFISH: menus, glass and fullscreen hints attached");
            emit changed();
        }
        const QRect rect = m_rect.intersected(QRect(0, 0, m_window->width(), m_window->height()));
        if (m_enabled && rect.width() > 0 && rect.height() > 0) {
            m_glass.set(s, rect.x(), rect.y(), rect.width(), rect.height(), 19);
            m_glass.set_glass(s);
            m_glass.set_glass_material(s, wl_fixed_from_double(1.2), wl_fixed_from_double(19), wl_fixed_from_double(8),
                wl_fixed_from_double(1.45), wl_fixed_from_double(4), wl_fixed_from_double(20), wl_fixed_from_double(0));
            const uint32_t tone = m_dark ? 8500 : 65535;
            m_glass.set_glass_tint(s, tone, tone, tone, m_dark ? 42000 : 38000);
        } else m_glass.unset(s);
        // Do not commit independently of Qt's buffer lifecycle. Ask Qt for a frame.
        m_window->requestUpdate();
    }
    Menus m_menus;
    Glass m_glass;
    Hints m_hints;
    std::unique_ptr<MenuNode> m_tree;
    QPointer<QWindow> m_window;
    wl_surface *m_bound = nullptr;
    QString m_json = "[]";
    QRect m_rect;
    bool m_enabled = true, m_dark = false, m_scheduled = false;
    int m_offset = 0, m_duration = 200;
};

class CutefishPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override { qmlRegisterType<CutefishWindow>(uri, 1, 0, "CutefishWindow"); }
};
#include "integration.moc"
