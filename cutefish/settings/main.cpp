// makOS adapter to the original Cutefish Settings service clients.
// No service is simulated and no privileged helper or shell command is used.
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSocketNotifier>
#include <QTimer>
#include <base/event_loop.h>
#include <cutefish/audio/backend.h>
#include <cutefish/bluez/manager.h>
#include <cutefish/display/display_client.h>
#include <cutefish/networkmanager/client.h>
#include <cutefish/networkmanager/variants.h>
#include <cutefish/powerprofiles/power_profiles.h>
#include <cutefish/upower/battery_status.h>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <functional>
#include <fcntl.h>
#include <unistd.h>

namespace dbus = cutefish::base::dbus;
namespace nmv = cutefish::networkmanager::variants;
using AudioObject = cutefish::audio::AudioObject;
static QString qs(const std::string& s) { return QString::fromStdString(s); }
static void output(const QJsonObject& object)
{
    const QByteArray bytes = QJsonDocument(object).toJson(QJsonDocument::Compact) + '\n';
    fwrite(bytes.constData(), 1, size_t(bytes.size()), stdout);
    fflush(stdout);
}

class SettingsBackend
{
    cutefish::audio::Backend audio;
    cutefish::networkmanager::Client network{dbus::Connection::system()};
    cutefish::bluez::Manager bluetooth{dbus::Connection::system(), true};
    cutefish::powerprofiles::PowerProfiles power;
    cutefish::upower::BatteryStatus battery;
    cutefish::display::DisplayClient display;
    cutefish::base::Subscription audioError;
    dbus::PendingCall propertyWrite, propertyRead;
    std::unique_ptr<dbus::Proxy> propertyProxy;
    QString pendingId;
    std::function<bool()> observed;
    QElapsedTimer pendingTime;
    bool writeReplied = false;
    QByteArray previousState;
public:
    SettingsBackend()
    {
        audioError = audio.operationFailed.connect([this](const std::string& error) {
            if (!pendingId.isEmpty()) finish(false, qs(error));
        });
    }
    QJsonObject snapshot() const
    {
        QJsonArray sinks, sources;
        for (const auto& node : audio.objects()) {
            if (node->kind() != AudioObject::Sink && node->kind() != AudioObject::Source) continue;
            QJsonObject entry{{"id", QString::number(node->index())}, {"name", qs(node->displayName())},
                {"volume", node->volume()}, {"muted", node->muted()}, {"writable", node->volumeWritable()},
                {"default", node->isDefault()}, {"type", node->isVirtualDevice() ? "Virtual" : node->bus().empty() ? "Audio" : qs(node->bus())}};
            (node->kind() == AudioObject::Sink ? sinks : sources).append(entry);
        }
        QJsonArray interfaces;
        bool hasWifi = false;
        for (const auto& path : network.devices()) {
            auto type = network.deviceType(path);
            if (type != 1 && type != 2) continue;
            hasWifi |= type == 2;
            auto active = network.activeConnection(path);
            interfaces.append(QJsonObject{{"id", qs(path)},
                {"name", qs(nmv::toString(network.property(path, "org.freedesktop.NetworkManager.Device", "Interface")))},
                {"type", type == 2 ? "Wi-Fi" : "Ethernet"}, {"state", int(network.deviceState(path))},
                {"connection", qs(nmv::toString(network.property(active, "org.freedesktop.NetworkManager.Connection.Active", "Id")))}});
        }
        bool networkAvailable = network.ready() && !network.owner().empty();
        auto permission = network.permission("org.freedesktop.NetworkManager.enable-disable-wifi");
        // An authorization dialog is not implemented here: only preauthorized writes.
        bool wifiWritable = networkAvailable && hasWifi && permission == "yes" && nmv::toBool(network.manager("WirelessHardwareEnabled"));
        QJsonArray adapters, devices;
        for (const auto& adapter : bluetooth.adapters()) {
            adapters.append(QJsonObject{{"id", qs(adapter->path())}, {"name", qs(adapter->name())},
                {"powered", adapter->powered()}, {"writable", bluetooth.operational() && !bluetooth.hardwareBlocked()}});
        }
        for (const auto& device : bluetooth.devices()) {
            devices.append(QJsonObject{{"name", qs(device->name())}, {"paired", device->paired()},
                {"connected", device->connected()}, {"battery", device->batteryPercentage()}});
        }
        QJsonArray profiles;
        for (const auto& profile : power.profiles()) profiles.append(qs(profile));
        QJsonArray monitors;
        if (display.loaded()) for (const auto& monitor : display.state().logical) {
            monitors.append(QJsonObject{{"id", qs(monitor.id)}, {"name", qs(monitor.waylandName)},
                {"width", monitor.width}, {"height", monitor.height}, {"scale", double(monitor.scale120) / 120.0},
                {"primary", monitor.primary}, {"x", monitor.x}, {"y", monitor.y}});
        }
        return {{"audio", QJsonObject{{"available", audio.isConnected()}, {"outputs", sinks}, {"inputs", sources}}},
            {"network", QJsonObject{{"available", networkAvailable}, {"wifiPresent", hasWifi}, {"wifiWritable", wifiWritable},
                {"wifiEnabled", nmv::toBool(network.manager("WirelessEnabled"))},
                {"wifiHardwareEnabled", nmv::toBool(network.manager("WirelessHardwareEnabled"))}, {"interfaces", interfaces}}},
            {"bluetooth", QJsonObject{{"available", bluetooth.available()}, {"ready", bluetooth.ready()},
                {"hardwareBlocked", bluetooth.hardwareBlocked()}, {"adapters", adapters}, {"devices", devices}}},
            {"power", QJsonObject{{"available", power.isReady() && !profiles.isEmpty()}, {"profiles", profiles},
                {"active", qs(power.activeProfile())}, {"degraded", qs(power.performanceDegraded())}}},
            {"battery", QJsonObject{{"available", battery.isAvailable()}, {"ready", battery.isReady()},
                {"percent", battery.chargePercent()}, {"onBattery", battery.onBattery()}, {"status", qs(battery.statusString())}}},
            {"display", QJsonObject{{"available", display.available() && display.loaded()}, {"monitors", monitors}, {"writable", false}}}};
    }
    void publish(bool force = false)
    {
        auto state = snapshot();
        QByteArray encoded = QJsonDocument(state).toJson(QJsonDocument::Compact);
        if (force || encoded != previousState) {
            previousState = encoded;
            output({{"type", "state"}, {"protocol", 1}, {"state", state}});
        }
    }
    void finish(bool ok, const QString& message = {})
    {
        if (pendingId.isEmpty()) return;
        const QString id = std::exchange(pendingId, {});
        observed = {};
        publish(true);
        output({{"type", "result"}, {"id", id}, {"ok", ok}, {"message", message}});
    }
    void tick()
    {
        if (!pendingId.isEmpty()) {
            if (writeReplied && observed && observed()) finish(true);
            else if (pendingTime.elapsed() >= 6000) finish(false, "The service did not confirm the requested value. Its current state is shown.");
        }
        publish();
    }
    // The same Cutefish D-Bus transport used by its Settings clients. A Set
    // reply alone is not success: Get must report the value and the original
    // client's live state must agree. No optimistic cache is exposed.
    void setProperty(const std::string& service, const std::string& path, const std::string& interface,
                     const std::string& property, const dbus::Variant& value, const QJsonValue& expected)
    {
        propertyProxy = std::make_unique<dbus::Proxy>(dbus::Connection::system(), service, path, interface);
        propertyProxy->setTimeout(std::chrono::seconds(4));
        const QString id = pendingId;
        propertyWrite = propertyProxy->setPropertyAsync(property, value, [this, id, property, expected](const dbus::Reply& reply) {
            if (pendingId != id) return;
            if (reply.isError()) { finish(false, qs(reply.error().message)); return; }
            propertyRead = propertyProxy->getPropertyAsync(property, [this, id, expected](const dbus::Reply& read) {
                if (pendingId != id) return;
                if (read.isError()) { finish(false, qs(read.error().message)); return; }
                auto value = read.value<dbus::Variant>();
                bool matches = value && ((expected.isBool() && value->get<bool>() == std::optional<bool>(expected.toBool())) ||
                    (expected.isString() && value->get<std::string>() == std::optional<std::string>(expected.toString().toStdString())));
                if (!matches) { finish(false, "The service readback differs from the requested value."); return; }
                writeReplied = true;
                tick();
            });
        });
    }
    void command(const QJsonObject& command)
    {
        const QString id = command.value("id").toString();
        const QString action = command.value("action").toString();
        if (action == "refresh") { display.refresh(); battery.refresh(); bluetooth.refresh(); publish(true); return; }
        if (id.isEmpty() || id.size() > 64) return;
        if (!pendingId.isEmpty()) { output({{"type", "result"}, {"id", id}, {"ok", false}, {"message", "Another change is awaiting readback."}}); return; }
        pendingId = id; writeReplied = false; pendingTime.start();
        const auto value = command.value("value");
        const QString target = command.value("target").toString();
        if (action.startsWith("audio.")) {
            bool validId = false;
            const auto index = target.toUInt(&validId);
            auto node = validId ? audio.object(index) : nullptr;
            if (!audio.isConnected() || !node || (node->kind() != AudioObject::Sink && node->kind() != AudioObject::Source)) {
                finish(false, "This audio device is unavailable."); return;
            }
            if (action == "audio.volume" && value.isDouble() && std::isfinite(value.toDouble()) && value.toDouble() >= 0 && value.toDouble() <= 1 && node->volumeWritable()) {
                double requested = value.toDouble();
                observed = [this, index, requested] { auto live = audio.object(index); return live && std::abs(live->volume() - requested) < 0.005; };
                node->setVolume(requested);
            } else if (action == "audio.muted" && value.isBool() && node->volumeWritable()) {
                bool requested = value.toBool();
                observed = [this, index, requested] { auto live = audio.object(index); return live && live->muted() == requested; };
                node->setMuted(requested);
            } else if (action == "audio.default" && value == QJsonValue(true)) {
                observed = [this, index] { auto live = audio.object(index); return live && live->isDefault(); };
                node->setDefault(true);
            } else { finish(false, "This audio action is unavailable or invalid."); return; }
            // AudioObject never changes volume/default optimistically. Readback
            // comes from PipeWire events, including permission/daemon errors.
            writeReplied = true;
        } else if (action == "wifi.enabled" && value.isBool()) {
            if (!snapshot()["network"].toObject()["wifiWritable"].toBool()) { finish(false, "Wi-Fi is unavailable, blocked, or requires administrator authorization."); return; }
            bool requested = value.toBool();
            observed = [this, requested] { return network.ready() && !network.owner().empty() && nmv::toBool(network.manager("WirelessEnabled")) == requested; };
            setProperty(network.owner(), "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager", "WirelessEnabled", dbus::Variant(requested), value);
        } else if (action == "bluetooth.powered" && value.isBool()) {
            auto adapter = bluetooth.object(target.toStdString());
            if (!bluetooth.operational() || bluetooth.hardwareBlocked() || !adapter || !adapter->isAdapter()) { finish(false, "This Bluetooth adapter is unavailable or hardware blocked."); return; }
            bool requested = value.toBool();
            observed = [this, target, requested] { auto live = bluetooth.object(target.toStdString()); return bluetooth.operational() && live && live->isAdapter() && live->powered() == requested; };
            setProperty("org.bluez", target.toStdString(), "org.bluez.Adapter1", "Powered", dbus::Variant(requested), value);
        } else if (action == "power.profile" && value.isString()) {
            const std::string requested = value.toString().toStdString();
            if (!power.isReady() || std::find(power.profiles().begin(), power.profiles().end(), requested) == power.profiles().end()) { finish(false, "This power profile is not provided by the service."); return; }
            observed = [this, requested] { return power.isReady() && power.activeProfile() == requested; };
            // Do not call PowerProfiles::setActiveProfile: it updates its cache
            // optimistically. Use its exact service contract and verify Get.
            setProperty("org.freedesktop.UPower.PowerProfiles", "/org/freedesktop/UPower/PowerProfiles", "org.freedesktop.UPower.PowerProfiles", "ActiveProfile", dbus::Variant(requested), value);
        } else { finish(false, "This setting is not implemented."); return; }
        tick();
    }
};

int main(int argc, char** argv)
{
    QCoreApplication app(argc, argv);
    cutefish::base::EventLoop loop;
    SettingsBackend backend;
    QSocketNotifier nativeEvents(loop.fd(), QSocketNotifier::Read);
    QObject::connect(&nativeEvents, &QSocketNotifier::activated, [&] { loop.dispatch(); });
    const int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
    QSocketNotifier input(STDIN_FILENO, QSocketNotifier::Read);
    QByteArray buffer;
    QObject::connect(&input, &QSocketNotifier::activated, [&] {
        char chunk[4096];
        auto count = read(STDIN_FILENO, chunk, sizeof(chunk));
        if (count == 0) { app.quit(); return; }
        if (count < 0) return;
        buffer.append(chunk, qsizetype(count));
        if (buffer.size() > 65536) { app.exit(2); return; }
        while (buffer.contains('\n')) {
            auto line = buffer.first(buffer.indexOf('\n'));
            buffer.remove(0, line.size() + 1);
            QJsonParseError error;
            const auto document = QJsonDocument::fromJson(line, &error);
            if (error.error == QJsonParseError::NoError && document.isObject()) backend.command(document.object());
        }
    });
    QTimer tick;
    tick.setInterval(200);
    QObject::connect(&tick, &QTimer::timeout, [&] { backend.tick(); });
    tick.start();
    backend.publish(true);
    return app.exec();
}
