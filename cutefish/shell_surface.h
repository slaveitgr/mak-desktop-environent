#pragma once
#include <QGuiApplication>
#include <QWindow>
#include <QPointer>
#include <QPlatformSurfaceEvent>
#include <QTimer>
#include <QWaylandClientExtension>
#include <QtGui/qpa/qplatformnativeinterface.h>
#include <functional>
#include <memory>
#include "qwayland-cutefish-shell-v1.h"

class ShellExtension : public QWaylandClientExtensionTemplate<ShellExtension>, public QtWayland::cutefish_shell_v1 {
public:
    ShellExtension() : QWaylandClientExtensionTemplate(2) {}
    ~ShellExtension() { if (isActive()) destroy(); }
    uint32_t negotiatedVersion() const { return QtWayland::cutefish_shell_v1::version(); }
};
class ShellMetadata : public QtWayland::cutefish_shell_surface_v1 {
public:
    explicit ShellMetadata(::cutefish_shell_surface_v1 *p) : QtWayland::cutefish_shell_surface_v1(p) {}
    ~ShellMetadata() override { destroy(); }
    std::function<void(QRect)> workArea;
    void cutefish_shell_surface_v1_work_area(int32_t x, int32_t y, int32_t w, int32_t h) override {
        if (workArea) workArea(QRect(x,y,w,h));
    }
};
// Only the compositor's one trusted connection can bind this private protocol.
class CutefishShellSurface : public QObject {
    Q_OBJECT
    Q_PROPERTY(QWindow* window READ window WRITE setWindow NOTIFY changed)
    Q_PROPERTY(int role READ role WRITE setRole NOTIFY changed)
    Q_PROPERTY(QPoint position READ position WRITE setPosition NOTIFY changed)
    Q_PROPERTY(int exclusiveZone READ exclusiveZone WRITE setExclusiveZone NOTIFY changed)
    Q_PROPERTY(int edge READ edge WRITE setEdge NOTIFY changed)
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(QRect workArea READ workArea NOTIFY changed)
public:
    explicit CutefishShellSurface(QObject *parent=nullptr) : QObject(parent) {
        connect(&m_extension,&QWaylandClientExtension::activeChanged,this,[this]{ schedule(); });
    }
    ~CutefishShellSurface() override { m_metadata.reset(); if(m_window)m_window->removeEventFilter(this); }
    QWindow *window() const { return m_window; }
    int role() const { return m_role; }
    QPoint position() const { return m_position; }
    int exclusiveZone() const { return m_zone; }
    int edge() const { return m_edge; }
    bool active() const { return bool(m_metadata); }
    QRect workArea() const { return m_workArea; }
    void setWindow(QWindow *w) {
        if(w==m_window)return;
        if(m_window)m_window->removeEventFilter(this);
        m_metadata.reset();m_bound=nullptr;m_window=w;
        if(w)w->installEventFilter(this);
        schedule();emit changed();
    }
    void setRole(int v) { if(v<0||v>3||v==m_role)return;m_role=v;schedule();emit changed(); }
    void setPosition(QPoint v) { if(v==m_position)return;m_position=v;schedule();emit changed(); }
    void setExclusiveZone(int v) { v=qBound(0,v,4096);if(v==m_zone)return;m_zone=v;schedule();emit changed(); }
    void setEdge(int v) { if(v<0||v>3||v==m_edge)return;m_edge=v;schedule();emit changed(); }
signals:
    void changed();
protected:
    bool eventFilter(QObject *,QEvent *event) override {
        if(event->type()==QEvent::PlatformSurface) {
            auto e=static_cast<QPlatformSurfaceEvent*>(event);
            if(e->surfaceEventType()==QPlatformSurfaceEvent::SurfaceAboutToBeDestroyed) {
                m_metadata.reset();m_bound=nullptr;emit changed();
            } else schedule();
        } else if(event->type()==QEvent::Show||event->type()==QEvent::Expose) schedule();
        return false;
    }
private:
    void schedule() { if(m_scheduled)return;m_scheduled=true;QTimer::singleShot(0,this,[this]{m_scheduled=false;apply();}); }
    void apply() {
        if(!m_window||!m_window->handle()||!m_extension.isActive()||m_extension.negotiatedVersion()<2)return;
        auto s=static_cast<wl_surface*>(QGuiApplication::platformNativeInterface()->nativeResourceForWindow("surface",m_window));
        if(!s)return;
        if(s!=m_bound) {
            m_metadata=std::make_unique<ShellMetadata>(m_extension.get_shell_surface(s));m_bound=s;
            m_metadata->workArea=[this](QRect r){m_workArea=r;emit changed();};
            qInfo("MAKOS_SHELL_SURFACE: role=%d",m_role);
        }
        m_metadata->set_role(uint32_t(m_role));
        m_metadata->set_focus_policy(m_role==0?0:1);
        m_metadata->set_position(m_position.x(),m_position.y());
        m_metadata->set_panel_behavior(0);
        if(m_zone>0)m_metadata->set_exclusive_zone(uint32_t(m_edge),m_zone,m_role==2?1:0);
        else m_metadata->clear_exclusive_zone();
        m_window->requestUpdate();emit changed();
    }
    ShellExtension m_extension;
    std::unique_ptr<ShellMetadata> m_metadata;
    QPointer<QWindow> m_window;
    wl_surface *m_bound=nullptr;
    int m_role=0,m_zone=0,m_edge=0;
    bool m_scheduled=false;
    QPoint m_position;
    QRect m_workArea;
};
