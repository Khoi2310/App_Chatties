#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QTimer>
#include <QString>
#include <QJsonObject>
#include <QJsonArray>
#include <QVariantList>
#include <QNetworkAccessManager>

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
    Q_INVOKABLE void sendMessage(const QString& content, int replyToId = 0,
                                 const QVariantList& attachments = {});

    // Mở hộp thoại chọn file (native); trả "" nếu hủy.
    Q_INVOKABLE QString chooseFile();
    // Tải file lên media server (HTTP); phát attachmentUploaded khi xong.
    Q_INVOKABLE void uploadAttachment(const QString& localPathOrUrl);
    Q_INVOKABLE void updateProfileAvatar(const QString& avatarUrl);
    Q_INVOKABLE void updateProfile(const QString& displayName, const QString& bio);
    Q_INVOKABLE void requestUserProfile(int userId);
    Q_INVOKABLE void editMessage(int messageId, const QString& content);
    Q_INVOKABLE void deleteMessage(int messageId);
    Q_INVOKABLE void toggleReaction(int messageId, const QString& emoji);

    // Tìm GIF qua server proxy (Giphy)
    Q_INVOKABLE void searchGifs(const QString& query);

    // Custom emoji theo từng server (qua HTTP media server)
    Q_INVOKABLE void fetchCustomEmojis(int serverId);
    Q_INVOKABLE void uploadCustomEmoji(int serverId, const QString& shortcode,
                                       const QString& localPathOrUrl);

    // Server (guild) & channel
    Q_INVOKABLE void createServer(const QString& name);
    Q_INVOKABLE void joinServer(int serverId);
    Q_INVOKABLE void createChannel(int serverId, const QString& name);
    Q_INVOKABLE void selectChannel(int channelId);

signals:
    void connected();
    void disconnected();
    void authOk(int userId, QString username, QString displayName, QString avatarUrl, QString bio);
    void authError(QString reason);
    void serversReceived(QJsonArray servers);
    void channelHistory(int channelId, QJsonArray messages);
    void messageReceived(QJsonObject message);
    void messageUpdated(int id, QString content, qint64 editedAt);
    void messageDeleted(int id);
    void reactionUpdated(int messageId, QVariantList reactions);
    void attachmentUploaded(QString url, QString kind, QString filename, int size);
    void customEmojisReceived(QVariantList emojis);   // [{shortcode, url}]
    void gifResults(QVariantList gifs);               // [{url, preview, width, height}]
    void profileUpdated(QString avatarUrl, QString displayName, QString bio);
    void userProfileReceived(int userId, QString username, QString displayName, QString avatarUrl, QString bio);
    void uploadFailed(QString reason);
    void errorReceived(QString reason);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onErrorOccurred();
    void tryReconnect();

private:
    void sendOp(const QString& op, const QJsonObject& data);

    QTcpSocket*             socket_;
    QTimer*                 reconnectTimer_;
    QNetworkAccessManager*  netManager_;
    QString                 host_;
    quint16                 port_ = 0;
    int                     currentChannelId_ = 0;
};
