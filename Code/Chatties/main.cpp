#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include <QSystemTrayIcon>
#include <QQuickWindow>
#include <QStyle>
#include "chatclient.h"
#include "messagemodel.h"

int main(int argc, char* argv[])
{
    QApplication::setAttribute(Qt::AA_UseHighDpiPixmaps, true);
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling, true);

    QApplication app(argc, argv);

    app.setWindowIcon(QIcon(":/app_icon.png"));

    // [Auth] Định danh cho QSettings (nhớ đăng nhập).
    QCoreApplication::setOrganizationName("Chatties");
    QCoreApplication::setApplicationName("Chatties");

    // Dùng style Material để có giao diện tối hiện đại.
    QQuickStyle::setStyle("Material");

    ChatClient   chatClient;
    MessageModel messageModel;

    // Cập nhật model từ tín hiệu mạng (giữ logic ở C++).
    QObject::connect(&chatClient, &ChatClient::channelHistory,
                     &messageModel, [&messageModel](int, const QJsonArray& msgs) {
                         messageModel.loadHistory(msgs);
                     });
    QObject::connect(&chatClient, &ChatClient::messageReceived,
                     &messageModel, &MessageModel::appendMessage);
    QObject::connect(&chatClient, &ChatClient::messageUpdated,
                     &messageModel, &MessageModel::updateMessage);
    QObject::connect(&chatClient, &ChatClient::messageDeleted,
                     &messageModel, &MessageModel::markDeleted);
    QObject::connect(&chatClient, &ChatClient::reactionUpdated,
                     &messageModel, &MessageModel::setReactions);

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("chatClient",   &chatClient);
    engine.rootContext()->setContextProperty("messageModel", &messageModel);

    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed,
        &app, []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("Chatties", "Main");

    // [Polish] Khay hệ thống + thông báo desktop khi bị @nhắc lúc cửa sổ không active.
    QQuickWindow* win = engine.rootObjects().isEmpty()
        ? nullptr
        : qobject_cast<QQuickWindow*>(engine.rootObjects().first());

    QSystemTrayIcon tray;
    tray.setIcon(!app.windowIcon().isNull()
                 ? app.windowIcon()
                 : app.style()->standardIcon(QStyle::SP_MessageBoxInformation));
    tray.setToolTip("Chatties");
    if (QSystemTrayIcon::isSystemTrayAvailable())
        tray.show();

    QObject::connect(&chatClient, &ChatClient::mentionPinged, &app,
        [&tray, win](int, int, int, const QString& author) {
            if (!win || !win->isActive()) {
                tray.showMessage(author + " mentioned you",
                                 QStringLiteral("You were mentioned in Chatties"),
                                 QSystemTrayIcon::Information, 5000);
            }
        });
    QObject::connect(&tray, &QSystemTrayIcon::messageClicked, &app, [win]() {
        if (win) { win->show(); win->raise(); win->requestActivate(); }
    });

    chatClient.connectToServer("127.0.0.1", 8080);

    return app.exec();
}
