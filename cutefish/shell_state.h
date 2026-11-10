#pragma once
#include <QObject>
#include <QTimer>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>
#include <QVariantList>
#include <QHash>
#include <QRect>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <functional>

// Session-local compositor bridge. All window actions name an observed window;
// menu commands retain their owning window ID and cannot target another app.
class CutefishShellState : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList windows READ windows NOTIFY changed)
    Q_PROPERTY(QVariantList menus READ menus NOTIFY changed)
    Q_PROPERTY(QString activeId READ activeId NOTIFY changed)
    Q_PROPERTY(QString activeAppId READ activeAppId NOTIFY changed)
    Q_PROPERTY(QString errorText READ errorText NOTIFY changed)
public:
    explicit CutefishShellState(QObject *parent=nullptr):QObject(parent) {
        QDBusConnection::sessionBus().connect("org.cutefish.WindowDebug1", "/org/cutefish/WindowDebug1",
            "org.cutefish.WindowDebug1", "LauncherToggleRequested", this, SLOT(receiveLauncherToggle()));
        m_timer.setInterval(300);connect(&m_timer,&QTimer::timeout,this,&CutefishShellState::refresh);m_timer.start();
        QTimer::singleShot(0,this,&CutefishShellState::refresh);
    }
    QVariantList windows() const{return m_windows;}
    QVariantList menus() const{return m_menus;}
    QString activeId() const{return m_activeId;}
    QString activeAppId() const{return m_activeAppId;}
    QString errorText() const{return m_error;}
    Q_INVOKABLE void refresh() {
        if(m_polling)return;m_polling=true;
        call("ListWindows",{},[this](QDBusMessage reply){
            m_polling=false;
            if(reply.type()==QDBusMessage::ErrorMessage){fail(reply.errorMessage());return;}
            m_timer.setInterval(300);m_error.clear();
            auto document=QJsonDocument::fromJson(reply.arguments().value(0).toString().toUtf8());
            if(!document.isArray()){fail("Invalid compositor window state");return;}
            QVariantList next;QString active,appId;
            for(auto value:document.array()){
                auto row=value.toObject();auto role=row.value("role").toString();
                if(role!="normal"||row.value("popup").toBool()||row.value("appId").toString()=="org.makos.Shell")continue;
                QString id=row.value("id").toVariant().toString();if(id.isEmpty())continue;
                row["id"]=id;next.append(row.toVariantMap());
                if(row.value("active").toBool()){active=id;appId=row.value("appId").toString();}
            }
            bool changedState=next!=m_windows||active!=m_activeId||appId!=m_activeAppId;
            m_windows=next;m_activeId=active;m_activeAppId=appId;
            for(auto it=m_targets.begin();it!=m_targets.end();)if(!observed(it.key()))it=m_targets.erase(it);else ++it;
            if(changedState)emit changed();
            if(active.isEmpty()){if(!m_menus.isEmpty()){m_menus.clear();emit changed();}return;}
            fetchMenu(active);
        });
    }
    Q_INVOKABLE void activate(const QString& id){action("RestoreWindow",id);action("ActivateWindow",id);}
    Q_INVOKABLE void minimize(const QString& id){action("MinimizeWindow",id);}
    Q_INVOKABLE void closeWindow(const QString& id){action("CloseWindow",id);}
    Q_INVOKABLE void fullscreen(const QString& id,bool enabled){action("SetWindowFullscreen",id,{enabled});}
    Q_INVOKABLE void minimizeTarget(const QString& id,int x,int y,int width,int height){
        QRect target(x,y,width,height);
        if(width>0&&height>0&&width<4096&&height<4096&&observed(id)&&m_targets.value(id)!=target){m_targets[id]=target;action("SetMinimizeTarget",id,{x,y,width,height});}
    }
    Q_INVOKABLE void menuEvent(const QString& id,int item,const QString& event){
        if(item<0||!QStringList{"prepare","opened","closed","activate"}.contains(event))return;
        action("MenuEvent",id,{item,event});
    }
signals:
    void changed();
    void launcherToggleRequested();
private slots:
    void receiveLauncherToggle(){emit launcherToggleRequested();}
private:
    void fail(const QString& error){m_error=error;m_timer.setInterval(3000);emit changed();}
    void call(const QString& method,const QVariantList& arguments,std::function<void(QDBusMessage)> done){
        auto message=QDBusMessage::createMethodCall("org.cutefish.WindowDebug1","/org/cutefish/WindowDebug1","org.cutefish.WindowDebug1",method);
        message.setArguments(arguments);message.setAutoStartService(false);
        auto watcher=new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message,1200),this);
        connect(watcher,&QDBusPendingCallWatcher::finished,this,[watcher,done]{auto reply=watcher->reply();watcher->deleteLater();done(reply);});
    }
    bool observed(const QString& id)const{for(auto value:m_windows)if(value.toMap().value("id").toString()==id)return true;return false;}
    QVariant windowId(const QString& id)const{return QVariant::fromValue<qulonglong>(id.toULongLong());}
    void action(const QString& method,const QString& id,QVariantList tail={}){
        bool valid=false;id.toULongLong(&valid);if(!valid||!observed(id))return;
        tail.prepend(windowId(id));
        call(method,tail,[this](QDBusMessage reply){if(reply.type()==QDBusMessage::ErrorMessage)fail(reply.errorMessage());else refresh();});
    }
    void fetchMenu(const QString& id){
        if(m_menuPending)return;m_menuPending=true;
        call("GetWindowMenu",{windowId(id)},[this,id](QDBusMessage reply){
            m_menuPending=false;if(id!=m_activeId)return;
            if(reply.type()==QDBusMessage::ErrorMessage){if(!m_menus.isEmpty()){m_menus.clear();emit changed();}return;}
            auto object=QJsonDocument::fromJson(reply.arguments().value(0).toString().toUtf8()).object();
            auto next=object.value("available").toBool()?object.value("items").toArray().toVariantList():QVariantList{};
            if(next!=m_menus){m_menus=next;emit changed();}
        });
    }
    QTimer m_timer;
    bool m_polling=false,m_menuPending=false;
    QVariantList m_windows,m_menus;
    QHash<QString,QRect> m_targets;
    QString m_activeId,m_activeAppId,m_error;
};
