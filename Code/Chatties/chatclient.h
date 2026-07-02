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
    // [M6] Đánh dấu đã đọc channel tới message id.
    Q_INVOKABLE void markChannelRead(int channelId, int lastMsgId);

    // [M6-6B] Bạn bè & DM
    Q_INVOKABLE void sendFriendRequest(const QString& username);
    Q_INVOKABLE void acceptFriend(int userId);
    Q_INVOKABLE void removeFriend(int userId);
    Q_INVOKABLE void requestFriends();
    Q_INVOKABLE void openDm(int userId);
    Q_INVOKABLE void requestDmList();

    // [M7] Tìm kiếm & ghim
    Q_INVOKABLE void searchMessages(const QString& query, const QString& scope,
                                    int scopeId, int beforeId);
    Q_INVOKABLE void pinMessage(int channelId, int messageId);
    Q_INVOKABLE void unpinMessage(int channelId, int messageId);
    Q_INVOKABLE void requestPins(int channelId);
    Q_INVOKABLE void requestMembers(int serverId);   // [Polish] cho @-autocomplete
    Q_INVOKABLE void forwardMessage(int messageId, int targetChannelId);  // [Forward]
    Q_INVOKABLE qint64 getLocalFileSize(const QString& localPathOrUrl);
    Q_INVOKABLE void deleteCustomEmoji(int serverId, const QString& shortcode);
    Q_INVOKABLE void renameCustomEmoji(int serverId, const QString& oldShortcode,
                                       const QString& newShortcode);

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
    void customEmojiUploaded(QString shortcode, QString url);
    void customEmojiDeleted(QString shortcode);
    void customEmojiRenamed(QString oldShortcode, QString newShortcode);
    // [M6] Mentions & unread
    void unreadState(QVariantList channels);   // [{channel_id, unread, mentions}]
    void channelActivity(int channelId);       // có tin mới ở channel không xem
    void mentionPinged(int channelId, int serverId, int messageId, QString authorName);
    // [M6-6B] Bạn bè & DM
    void friendsReceived(QVariantList friends);   // [{user_id, username, display_name, avatar_url, status, incoming}]
    void dmListReceived(QVariantList dms);        // [{channel_id, user_id, username, display_name, avatar_url}]
    void dmOpened(int channelId, QVariantMap otherUser);
    // [M7] Tìm kiếm & ghim
    void searchResults(QString query, QVariantList results, bool hasMore);
    void pinsReceived(int channelId, QJsonArray pins);
    void pinsChanged(int channelId);
    void membersReceived(int serverId, QVariantList members);   // [Polish] @-autocomplete

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
