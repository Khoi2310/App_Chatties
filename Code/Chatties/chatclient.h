#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>

class ChatClient : public QObject {
    Q_OBJECT

public:
    explicit ChatClient(QObject* parent = nullptr);

    Q_INVOKABLE void connectToServer(const QString& host, quint16 port);

    // Giao thức theo "op envelope" — gọi được từ QML.
    Q_INVOKABLE void registerUser(const QString& username,
                                  const QString& email,
                                  const QString& password,
                                  const QString& displayName);
    Q_INVOKABLE void login(const QString& username, const QString& password);
    Q_INVOKABLE void sendMessage(const QString& content, int replyToId = 0);
    Q_INVOKABLE void editMessage(int messageId, const QString& content);
    Q_INVOKABLE void deleteMessage(int messageId);
    Q_INVOKABLE void toggleReaction(int messageId, const QString& emoji);

    // Server (guild) & channel
    Q_INVOKABLE void createServer(const QString& name);
    Q_INVOKABLE void joinServer(int serverId);
    Q_INVOKABLE void createChannel(int serverId, const QString& name);
    Q_INVOKABLE void selectChannel(int channelId);

signals:
    void connected();
    void disconnected();
    void authOk(int userId, QString username, QString displayName);
    void authError(QString reason);
    void serversReceived(QJsonArray servers);
    void channelHistory(int channelId, QJsonArray messages);
    void messageReceived(QJsonObject message);
    void messageUpdated(int id, QString content, qint64 editedAt);
    void messageDeleted(int id);
    void reactionUpdated(int messageId, QVariantList reactions);
    void errorReceived(QString reason);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onErrorOccurred();
    void tryReconnect();

private:
    void sendOp(const QString& op, const QJsonObject& data);

    QTcpSocket* socket_;
    QTimer*     reconnectTimer_;
    QString     host_;
    quint16     port_ = 0;
    int         currentChannelId_ = 0;
};
