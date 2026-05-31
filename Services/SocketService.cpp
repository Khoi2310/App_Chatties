#include "SocketService.h"

SocketService::SocketService(QObject *parent) : QObject(parent) {
    socket = new QTcpSocket(this);
    connect(socket, &QTcpSocket::connected, this, &SocketService::onConnected);
    connect(socket, &QTcpSocket::disconnected, this, &SocketService::onDisconnected);
    connect(socket, &QTcpSocket::readyRead, this, &SocketService::onReadyRead);
    connect(socket, &QTcpSocket::errorOccurred, this, &SocketService::onErrorOccurred);
}

void SocketService::connectToHost(const QString &ip, quint16 port) {
    if (socket->state() == QAbstractSocket::UnconnectedState) {
        socket->connectToHost(ip, port);
    }
}

void SocketService::disconnectFromHost() {
    if (socket->state() == QAbstractSocket::ConnectedState) {
        socket->disconnectFromHost();
    }
}

void SocketService::sendMessage(const QString &jsonStr) {
    if (socket->state() == QAbstractSocket::ConnectedState) {
        QString packet = jsonStr + "\n"; // Chuẩn format với server
        socket->write(packet.toUtf8());
        socket->flush();
    }
}

bool SocketService::isConnected() const {
    return socket->state() == QAbstractSocket::ConnectedState;
}

void SocketService::onConnected() { emit connectionSuccess(); }
void SocketService::onDisconnected() { emit connectionClosed(); }
void SocketService::onErrorOccurred(QAbstractSocket::SocketError socketError) {
    Q_UNUSED(socketError);
    emit connectionError(socket->errorString());
}

void SocketService::onReadyRead() {
    while (socket->canReadLine()) {
        QByteArray lineBytes = socket->readLine();
        QString lineStr = QString::fromUtf8(lineBytes).trimmed();
        if (!lineStr.isEmpty()) {
            emit messageReceived(lineStr);
        }
    }
}