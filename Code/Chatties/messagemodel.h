#pragma once
#include <QAbstractListModel>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>
#include <QVariantList>

class MessageModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        UsernameRole = Qt::UserRole + 1,
        ContentRole,
        TimestampRole,
        AuthorIdRole,
        MessageIdRole,
        ReplyToIdRole,
        ReplyUsernameRole,
        ReplyExcerptRole,
        EditedRole,
        DeletedRole,
        ReactionsRole,
        AttachmentsRole,
        AvatarUrlRole
    };

    struct Item {
        int     id        = 0;
        QString username;
        QString content;
        qint64  timestamp = 0;
        int     authorId  = 0;
        int     replyToId = 0;
        QString replyUsername;
        QString replyExcerpt;
        qint64  editedAt  = 0;
        bool    deleted   = false;
        QVariantList reactions;    // [{emoji, count}]
        QVariantList attachments;  // [{url, kind, filename, size}]
        QString avatarUrl;
    };

    explicit MessageModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

public slots:
    void appendMessage(const QJsonObject& msg);
    void loadHistory(const QJsonArray& messages);
    void clear();
    void updateMessage(int id, const QString& content, qint64 editedAt);
    void markDeleted(int id);
    void setReactions(int id, const QVariantList& reactions);

private:
    QVector<Item> items_;
};
