#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>
#include "chatclient.h"
#include "messagemodel.h"

int main(int argc, char* argv[])
{
    QApplication::setAttribute(Qt::AA_UseHighDpiPixmaps, true);
    QApplication::setAttribute(Qt::AA_EnableHighDpiScaling, true);

    QApplication app(argc, argv);

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

    chatClient.connectToServer("127.0.0.1", 8080);

    return app.exec();
}
