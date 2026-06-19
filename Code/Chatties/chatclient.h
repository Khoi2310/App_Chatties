#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>

class ChatClient : public QObject {
    Q_OBJECT

public:
    explicit ChatClient(QObject* parent = nullptr);

    void connectToServer(const QString& host, quint16 port);

    // Giao thức theo "op envelope"
    void registerUser(const QString& username,
                      const QString& password,
                      const QString& displayName);
    void login(const QString& username, const QString& password);
    void sendMessage(const QString& content);

signals:
    void connected();
    void disconnected();
    void authOk(int userId, QString username, QString displayName);
    void authError(QString reason);
    void historyReceived(QJsonArray messages);
    void messageReceived(QJsonObject message);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();

private:
    void sendOp(const QString& op, const QJsonObject& data);

    QTcpSocket* socket_;
};
