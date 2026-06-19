#include "chatclient.h"
#include <QJsonDocument>

ChatClient::ChatClient(QObject* parent)
    : QObject(parent)
    , socket_(new QTcpSocket(this))
{
    connect(socket_, &QTcpSocket::connected,
            this,    &ChatClient::onConnected);
    connect(socket_, &QTcpSocket::disconnected,
            this,    &ChatClient::onDisconnected);
    connect(socket_, &QTcpSocket::readyRead,
            this,    &ChatClient::onReadyRead);
}

void ChatClient::connectToServer(const QString& host, quint16 port) {
    socket_->connectToHost(host, port);
}

void ChatClient::sendOp(const QString& op, const QJsonObject& data) {
    QJsonObject env;
    env["op"]   = op;
    env["data"] = data;

    QJsonDocument doc(env);
    QString line = QString::fromUtf8(doc.toJson(QJsonDocument::Compact)) + "\n";
    socket_->write(line.toUtf8());
}

void ChatClient::registerUser(const QString& username,
                              const QString& password,
                              const QString& displayName) {
    QJsonObject data;
    data["username"]     = username;
    data["password"]     = password;
    data["display_name"] = displayName;
    sendOp("auth.register", data);
}

void ChatClient::login(const QString& username, const QString& password) {
    QJsonObject data;
    data["username"] = username;
    data["password"] = password;
    sendOp("auth.login", data);
}

void ChatClient::sendMessage(const QString& content) {
    QJsonObject data;
    data["content"] = content;
    sendOp("message.create", data);
}

void ChatClient::onConnected() {
    emit connected();
}

void ChatClient::onDisconnected() {
    emit disconnected();
}

void ChatClient::onReadyRead() {
    // Mỗi dòng là 1 gói JSON {op, data}
    while (socket_->canReadLine()) {
        QByteArray line = socket_->readLine();

        QJsonParseError err{};
        QJsonDocument doc = QJsonDocument::fromJson(line, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject())
            continue;

        QJsonObject env  = doc.object();
        QString     op   = env["op"].toString();
        QJsonObject data = env["data"].toObject();

        if (op == "auth.ok") {
            emit authOk(data["user_id"].toInt(),
                        data["username"].toString(),
                        data["display_name"].toString());
        } else if (op == "auth.error") {
            emit authError(data["reason"].toString());
        } else if (op == "ready") {
            emit historyReceived(data["recent_messages"].toArray());
        } else if (op == "message.create") {
            emit messageReceived(data);
        }
    }
}
