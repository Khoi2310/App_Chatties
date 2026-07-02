#include "chatclient.h"
#include <QDebug>
#include <QJsonDocument>
#include <QVariantMap>
#include <QFile>
#include <QFileInfo>
#include <QUrl>
#include <QNetworkRequest>
#include <QNetworkReply>
#include <QFileDialog>

ChatClient::ChatClient(QObject* parent)
    : QObject(parent)
    , socket_(new QTcpSocket(this))
    , reconnectTimer_(new QTimer(this))
    , netManager_(new QNetworkAccessManager(this))
{
    connect(socket_, &QTcpSocket::connected,
            this,    &ChatClient::onConnected);
    connect(socket_, &QTcpSocket::disconnected,
            this,    &ChatClient::onDisconnected);
    connect(socket_, &QTcpSocket::readyRead,
            this,    &ChatClient::onReadyRead);
    connect(socket_, &QTcpSocket::errorOccurred,
            this,    &ChatClient::onErrorOccurred);

    // Thử kết nối lại mỗi 2 giây cho đến khi thành công.
    reconnectTimer_->setInterval(2000);
    connect(reconnectTimer_, &QTimer::timeout,
            this, &ChatClient::tryReconnect);
}

void ChatClient::connectToServer(const QString& host, quint16 port) {
    host_ = host;
    port_ = port;
    reconnectTimer_->start();        // tiếp tục thử cho đến khi kết nối được
    socket_->connectToHost(host_, port_);
}

void ChatClient::tryReconnect() {
    if (socket_->state() == QAbstractSocket::UnconnectedState) {
        socket_->connectToHost(host_, port_);
    }
}

void ChatClient::onErrorOccurred() {
    // Kết nối thất bại (vd: server chưa bật) → đảm bảo vẫn đang thử lại.
    if (port_ != 0 && socket_->state() == QAbstractSocket::UnconnectedState) {
        reconnectTimer_->start();
    }
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
                              const QString& email,
                              const QString& password,
                              const QString& displayName) {
    QJsonObject data;
    data["username"]     = username;
    data["email"]        = email;
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

void ChatClient::sendMessage(const QString& content, int replyToId,
                             const QVariantList& attachments) {
    if (currentChannelId_ == 0) return;   // chưa chọn channel
    QJsonObject data;
    data["channel_id"] = currentChannelId_;
    data["content"]    = content;
    if (replyToId != 0)
        data["reply_to_id"] = replyToId;
    if (!attachments.isEmpty())
        data["attachments"] = QJsonArray::fromVariantList(attachments);
    sendOp("message.create", data);
}

QString ChatClient::chooseFile() {
    return QFileDialog::getOpenFileName(
        nullptr, tr("Choose a file"), QString(),
        tr("All files (*);;Images (*.png *.jpg *.jpeg *.gif *.webp)"));
}

void ChatClient::uploadAttachment(const QString& localPathOrUrl) {
    // Chấp nhận cả đường dẫn local lẫn URL "file://" (từ FileDialog).
    QString path = localPathOrUrl;
    if (path.startsWith("file:"))
        path = QUrl(path).toLocalFile();

    const qint64 MAX_UPLOAD = 5LL * 1024 * 1024;   // 5 MB
    if (QFileInfo(path).size() > MAX_UPLOAD) {
        emit uploadFailed(tr("File too large (max 5 MB)"));
        return;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        emit uploadFailed(tr("Cannot open file: ") + path);
        return;
    }
    const QByteArray bytes = file.readAll();
    file.close();

    const QString suffix = QFileInfo(path).suffix().toLower();
    QString contentType, kind;
    if      (suffix == "png")               { contentType = "image/png";  kind = "image"; }
    else if (suffix == "jpg" || suffix == "jpeg") { contentType = "image/jpeg"; kind = "image"; }
    else if (suffix == "gif")               { contentType = "image/gif";  kind = "gif"; }
    else if (suffix == "webp")              { contentType = "image/webp"; kind = "image"; }
    else {
        // Mọi loại file khác: tải lên như file đính kèm thông thường.
        contentType = "application/octet-stream";
        kind = "file";
    }

    const QString filename = QFileInfo(path).fileName();
    const int     fileSize = static_cast<int>(bytes.size());

    QNetworkRequest req(QUrl("http://127.0.0.1:8081/upload"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    req.setRawHeader("X-Filename", filename.toUtf8());

    QNetworkReply* reply = netManager_->post(req, bytes);
    connect(reply, &QNetworkReply::finished, this, [this, reply, kind, filename, fileSize]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit uploadFailed(reply->errorString());
            return;
        }
        const QJsonObject obj =
            QJsonDocument::fromJson(reply->readAll()).object();
        const QString url = obj.value("url").toString();
        if (url.isEmpty()) {
            emit uploadFailed(tr("Upload: empty url in response"));
            return;
        }
        emit attachmentUploaded(url, kind, filename, fileSize);
    });
}

void ChatClient::updateProfileAvatar(const QString& avatarUrl) {
    QJsonObject data;
    data["avatar_url"] = avatarUrl;
    sendOp("profile.update", data);
}

void ChatClient::updateProfile(const QString& displayName, const QString& bio) {
    QJsonObject data;
    data["display_name"] = displayName;
    data["bio"] = bio;
    sendOp("profile.update", data);
}

void ChatClient::requestUserProfile(int userId) {
    QJsonObject data;
    data["user_id"] = userId;
    sendOp("user.profile", data);
}

void ChatClient::editMessage(int messageId, const QString& content) {
    QJsonObject data;
    data["message_id"] = messageId;
    data["content"]    = content;
    sendOp("message.update", data);
}

void ChatClient::deleteMessage(int messageId) {
    QJsonObject data;
    data["message_id"] = messageId;
    sendOp("message.delete", data);
}

void ChatClient::toggleReaction(int messageId, const QString& emoji) {
    QJsonObject data;
    data["message_id"] = messageId;
    data["emoji"]      = emoji;
    sendOp("reaction.toggle", data);
}

void ChatClient::searchGifs(const QString& query) {
    QString url = "http://127.0.0.1:8081/gif_search?q=" +
                  QString::fromUtf8(QUrl::toPercentEncoding(query));
    QNetworkReply* reply = netManager_->get(QNetworkRequest(QUrl(url)));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        QVariantList list;
        for (const auto& v : arr) {
            const QJsonObject o = v.toObject();
            QVariantMap m;
            m["url"]     = o.value("url").toString();
            m["preview"] = o.value("preview").toString();
            m["width"]   = o.value("width").toInt();
            m["height"]  = o.value("height").toInt();
            list.append(m);
        }
        emit gifResults(list);
    });
}

void ChatClient::fetchCustomEmojis(int serverId) {
    QNetworkRequest req(QUrl("http://127.0.0.1:8081/emojis?server_id=" +
                             QString::number(serverId)));
    QNetworkReply* reply = netManager_->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) return;
        const QJsonArray arr = QJsonDocument::fromJson(reply->readAll()).array();
        QVariantList list;
        for (const auto& v : arr) {
            const QJsonObject o = v.toObject();
            QVariantMap m;
            m["shortcode"] = o.value("shortcode").toString();
            m["url"]       = o.value("url").toString();
            list.append(m);
        }
        emit customEmojisReceived(list);
    });
}

void ChatClient::uploadCustomEmoji(int serverId, const QString& shortcode,
                                   const QString& localPathOrUrl) {
    QString path = localPathOrUrl;
    if (path.startsWith("file:"))
        path = QUrl(path).toLocalFile();

    const qint64 MAX_EMOJI = 256 * 1024;   // 256 KB như Discord
    if (QFileInfo(path).size() > MAX_EMOJI) {
        emit uploadFailed(tr("Emoji too large (max 256 KB)"));
        return;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        emit uploadFailed(tr("Cannot open file: ") + path);
        return;
    }
    const QByteArray bytes = file.readAll();
    file.close();

    const QString suffix = QFileInfo(path).suffix().toLower();
    QString contentType = "image/png";
    if (suffix == "jpg" || suffix == "jpeg") contentType = "image/jpeg";
    else if (suffix == "gif")                contentType = "image/gif";

    QNetworkRequest req(QUrl("http://127.0.0.1:8081/upload_emoji"));
    req.setHeader(QNetworkRequest::ContentTypeHeader, contentType);
    req.setRawHeader("X-Emoji-Shortcode", shortcode.toUtf8());
    req.setRawHeader("X-Server-Id", QByteArray::number(serverId));

    QNetworkReply* reply = netManager_->post(req, bytes);
    connect(reply, &QNetworkReply::finished, this, [this, reply, serverId]() {
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit uploadFailed(reply->errorString());
            return;
        }
        fetchCustomEmojis(serverId);   // làm mới danh sách của server này
    });
}

void ChatClient::createServer(const QString& name) {
    QJsonObject data;
    data["name"] = name;
    sendOp("server.create", data);
}

void ChatClient::joinServer(int serverId) {
    QJsonObject data;
    data["server_id"] = serverId;
    sendOp("server.join", data);
}

void ChatClient::createChannel(int serverId, const QString& name) {
    QJsonObject data;
    data["server_id"] = serverId;
    data["name"]      = name;
    sendOp("channel.create", data);
}

void ChatClient::selectChannel(int channelId) {
    currentChannelId_ = channelId;
    QJsonObject data;
    data["channel_id"] = channelId;
    sendOp("channel.select", data);
}

void ChatClient::markChannelRead(int channelId, int lastMsgId) {
    QJsonObject data;
    data["channel_id"]       = channelId;
    data["last_read_msg_id"] = lastMsgId;
    sendOp("channel.read", data);
}

// [M6-6B] Bạn bè & DM
void ChatClient::sendFriendRequest(const QString& username) {
    QJsonObject data; data["username"] = username;
    sendOp("friend.request", data);
}
void ChatClient::acceptFriend(int userId) {
    QJsonObject data; data["user_id"] = userId;
    sendOp("friend.accept", data);
}
void ChatClient::removeFriend(int userId) {
    QJsonObject data; data["user_id"] = userId;
    sendOp("friend.remove", data);
}
void ChatClient::requestFriends() {
    sendOp("friend.list", QJsonObject());
}
void ChatClient::openDm(int userId) {
    QJsonObject data; data["user_id"] = userId;
    sendOp("dm.open", data);
}
void ChatClient::requestDmList() {
    sendOp("dm.list", QJsonObject());
}

void ChatClient::onConnected() {
    reconnectTimer_->stop();         // đã kết nối, ngừng thử lại
    emit connected();
}

void ChatClient::onDisconnected() {
    emit disconnected();
    if (port_ != 0) {
        reconnectTimer_->start();    // tự động kết nối lại
    }
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
                        data["display_name"].toString(),
                        data["avatar_url"].toString(),
                        data["bio"].toString());
        } else if (op == "auth.error") {
            emit authError(data["reason"].toString());
        } else if (op == "ready") {
            emit serversReceived(data["servers"].toArray());
        } else if (op == "channel.history") {
            emit channelHistory(data["channel_id"].toInt(),
                                data["messages"].toArray());
        } else if (op == "message.create") {
            emit messageReceived(data);
        } else if (op == "message.update") {
            emit messageUpdated(data["id"].toInt(),
                                data["content"].toString(),
                                static_cast<qint64>(data["edited_at"].toDouble()));
        } else if (op == "message.delete") {
            emit messageDeleted(data["id"].toInt());
        } else if (op == "reaction.update") {
            QVariantList list;
            const QJsonArray arr = data["reactions"].toArray();
            for (const auto& v : arr) {
                const QJsonObject o = v.toObject();
                QVariantMap m;
                m["emoji"] = o["emoji"].toString();
                m["count"] = o["count"].toInt();
                list.append(m);
            }
            emit reactionUpdated(data["message_id"].toInt(), list);
        } else if (op == "profile.ok") {
            emit profileUpdated(data["avatar_url"].toString(),
                                data["display_name"].toString(),
                                data["bio"].toString());
        } else if (op == "user.profile") {
            emit userProfileReceived(data["user_id"].toInt(),
                                     data["username"].toString(),
                                     data["display_name"].toString(),
                                     data["avatar_url"].toString(),
                                     data["bio"].toString());
        } else if (op == "unread.state") {
            QVariantList list;
            const QJsonArray arr = data["channels"].toArray();
            for (const auto& v : arr) {
                const QJsonObject o = v.toObject();
                QVariantMap m;
                m["channel_id"] = o["channel_id"].toInt();
                m["unread"]     = o["unread"].toInt();
                m["mentions"]   = o["mentions"].toInt();
                list.append(m);
            }
            emit unreadState(list);
        } else if (op == "channel.activity") {
            emit channelActivity(data["channel_id"].toInt());
        } else if (op == "mention.ping") {
            emit mentionPinged(data["channel_id"].toInt(),
                               data["server_id"].toInt(),
                               data["message_id"].toInt(),
                               data["author_name"].toString());
        } else if (op == "friend.list") {
            QVariantList list;
            const QJsonArray arr = data["friends"].toArray();
            for (const auto& v : arr) {
                const QJsonObject o = v.toObject();
                QVariantMap m;
                m["user_id"]      = o["user_id"].toInt();
                m["username"]     = o["username"].toString();
                m["display_name"] = o["display_name"].toString();
                m["avatar_url"]   = o["avatar_url"].toString();
                m["status"]       = o["status"].toString();
                m["incoming"]     = o["incoming"].toBool();
                list.append(m);
            }
            emit friendsReceived(list);
        } else if (op == "dm.list") {
            QVariantList list;
            const QJsonArray arr = data["dms"].toArray();
            for (const auto& v : arr) {
                const QJsonObject o = v.toObject();
                QVariantMap m;
                m["channel_id"]   = o["channel_id"].toInt();
                m["user_id"]      = o["user_id"].toInt();
                m["username"]     = o["username"].toString();
                m["display_name"] = o["display_name"].toString();
                m["avatar_url"]   = o["avatar_url"].toString();
                list.append(m);
            }
            emit dmListReceived(list);
        } else if (op == "dm.opened") {
            const QJsonObject ou = data["other_user"].toObject();
            QVariantMap m;
            m["user_id"]      = ou["user_id"].toInt();
            m["username"]     = ou["username"].toString();
            m["display_name"] = ou["display_name"].toString();
            m["avatar_url"]   = ou["avatar_url"].toString();
            emit dmOpened(data["channel_id"].toInt(), m);
        } else if (op == "error") {
            emit errorReceived(data["reason"].toString());
        }
    }
}

qint64 ChatClient::getLocalFileSize(const QString& localPathOrUrl) {
    QString path = localPathOrUrl;
    if (path.startsWith("file:"))
        path = QUrl(path).toLocalFile();

    QFileInfo fileInfo(path);
    return fileInfo.exists() ? fileInfo.size() : 0;
}

void ChatClient::deleteCustomEmoji(int serverId, const QString& shortcode) {
    QNetworkRequest req(QUrl("http://127.0.0.1:8081/delete_emoji"));
    req.setRawHeader("X-Emoji-Shortcode", shortcode.toUtf8());
    req.setRawHeader("X-Server-Id", QByteArray::number(serverId));

    QNetworkReply* reply = netManager_->post(req, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [this, reply, shortcode]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError)
            emit customEmojiDeleted(shortcode);
        else
            qWarning() << "[Client] delete emoji failed:" << reply->errorString();
    });
}

void ChatClient::renameCustomEmoji(int serverId, const QString& oldShortcode,
                                   const QString& newShortcode) {
    QNetworkRequest req(QUrl("http://127.0.0.1:8081/rename_emoji"));
    req.setRawHeader("X-Emoji-Old-Shortcode", oldShortcode.toUtf8());
    req.setRawHeader("X-Emoji-New-Shortcode", newShortcode.toUtf8());
    req.setRawHeader("X-Server-Id", QByteArray::number(serverId));

    QNetworkReply* reply = netManager_->post(req, QByteArray());
    connect(reply, &QNetworkReply::finished, this,
            [this, reply, oldShortcode, newShortcode]() {
        reply->deleteLater();
        if (reply->error() == QNetworkReply::NoError)
            emit customEmojiRenamed(oldShortcode, newShortcode);
        else
            qWarning() << "[Client] rename emoji failed:" << reply->errorString();
    });
}

