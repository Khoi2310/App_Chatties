#include "chatclient.h"
#include <QJsonObject>
#include <QJsonDocument>

ChatClient::ChatClient(QObject* parent)
    : QObject(parent)
    , socket_(new QTcpSocket(this))
{
    // Kết nối các signal của socket vào slot của class này
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

void ChatClient::sendMessage(int channelId, int senderId, const QString& content) {
    // Đóng gói thành JSON
    QJsonObject obj;
    obj["type"]       = "message";
    obj["channel_id"] = channelId;
    obj["sender_id"]  = senderId;
    obj["content"]    = content;

    QJsonDocument doc(obj);
    QString jsonStr = doc.toJson(QJsonDocument::Compact) + "\n"; // \n để server nhận đúng

    socket_->write(jsonStr.toUtf8());
}

void ChatClient::onConnected() {
    emit connected();
}

void ChatClient::onDisconnected() {
    emit disconnected();
}

void ChatClient::onReadyRead() {
    // Đọc toàn bộ dữ liệu server gửi về
    while (socket_->canReadLine()) {
        QString line = QString::fromUtf8(socket_->readLine()).trimmed();
        emit messageReceived(line);
    }
}