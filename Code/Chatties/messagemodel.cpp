#include "messagemodel.h"

MessageModel::MessageModel(QObject* parent)
    : QAbstractListModel(parent)
{}

int MessageModel::rowCount(const QModelIndex& parent) const {
    if (parent.isValid()) return 0;
    return items_.size();
}

QVariant MessageModel::data(const QModelIndex& index, int role) const {
    if (!index.isValid() || index.row() < 0 || index.row() >= items_.size())
        return {};

    const Item& it = items_.at(index.row());
    switch (role) {
        case UsernameRole:      return it.username;
        case ContentRole:       return it.content;
        case TimestampRole:     return it.timestamp;
        case AuthorIdRole:      return it.authorId;
        case MessageIdRole:     return it.id;
        case ReplyToIdRole:     return it.replyToId;
        case ReplyUsernameRole: return it.replyUsername;
        case ReplyExcerptRole:  return it.replyExcerpt;
        case EditedRole:        return it.editedAt != 0;
        case DeletedRole:       return it.deleted;
        case ReactionsRole:     return it.reactions;
        case AttachmentsRole:   return it.attachments;
        default:                return {};
    }
}

QHash<int, QByteArray> MessageModel::roleNames() const {
    return {
        { UsernameRole,      "username"      },
        { ContentRole,       "content"       },
        { TimestampRole,     "timestamp"     },
        { AuthorIdRole,      "authorId"      },
        { MessageIdRole,     "messageId"     },
        { ReplyToIdRole,     "replyToId"     },
        { ReplyUsernameRole, "replyUsername" },
        { ReplyExcerptRole,  "replyExcerpt"  },
        { EditedRole,        "edited"        },
        { DeletedRole,       "deleted"       },
        { ReactionsRole,     "reactions"     },
        { AttachmentsRole,   "attachments"   }
    };
}

static QVariantList reactionsFromJson(const QJsonArray& arr) {
    QVariantList list;
    for (const auto& v : arr) {
        const QJsonObject o = v.toObject();
        QVariantMap m;
        m["emoji"] = o.value("emoji").toString();
        m["count"] = o.value("count").toInt();
        list.append(m);
    }
    return list;
}

static QVariantList attachmentsFromJson(const QJsonArray& arr) {
    QVariantList list;
    for (const auto& v : arr) {
        const QJsonObject o = v.toObject();
        QVariantMap m;
        m["url"]      = o.value("url").toString();
        m["kind"]     = o.value("kind").toString();
        m["filename"] = o.value("filename").toString();
        m["size"]     = o.value("size").toInt();
        list.append(m);
    }
    return list;
}

static MessageModel::Item itemFromJson(const QJsonObject& o) {
    MessageModel::Item it;
    it.id            = o.value("id").toInt();
    it.username      = o.value("username").toString();
    it.content       = o.value("content").toString();
    it.timestamp     = static_cast<qint64>(o.value("timestamp").toDouble());
    it.authorId      = o.value("author_id").toInt();
    it.replyToId     = o.value("reply_to_id").toInt();
    it.replyUsername = o.value("reply_username").toString();
    it.replyExcerpt  = o.value("reply_excerpt").toString();
    it.editedAt      = static_cast<qint64>(o.value("edited_at").toDouble());
    it.deleted       = o.value("deleted").toBool();
    it.reactions     = reactionsFromJson(o.value("reactions").toArray());
    it.attachments   = attachmentsFromJson(o.value("attachments").toArray());
    return it;
}

void MessageModel::appendMessage(const QJsonObject& msg) {
    beginInsertRows(QModelIndex(), items_.size(), items_.size());
    items_.push_back(itemFromJson(msg));
    endInsertRows();
}

void MessageModel::loadHistory(const QJsonArray& messages) {
    beginResetModel();
    items_.clear();
    for (const auto& v : messages) {
        items_.push_back(itemFromJson(v.toObject()));
    }
    endResetModel();
}

void MessageModel::clear() {
    beginResetModel();
    items_.clear();
    endResetModel();
}

void MessageModel::updateMessage(int id, const QString& content, qint64 editedAt) {
    for (int i = 0; i < items_.size(); ++i) {
        if (items_[i].id == id) {
            items_[i].content  = content;
            items_[i].editedAt = editedAt;
            emit dataChanged(index(i), index(i), { ContentRole, EditedRole });
            return;
        }
    }
}

void MessageModel::markDeleted(int id) {
    for (int i = 0; i < items_.size(); ++i) {
        if (items_[i].id == id) {
            items_[i].deleted = true;
            items_[i].content.clear();
            items_[i].attachments.clear();
            emit dataChanged(index(i), index(i),
                             { ContentRole, DeletedRole, AttachmentsRole });
            return;
        }
    }
}

void MessageModel::setReactions(int id, const QVariantList& reactions) {
    for (int i = 0; i < items_.size(); ++i) {
        if (items_[i].id == id) {
            items_[i].reactions = reactions;
            emit dataChanged(index(i), index(i), { ReactionsRole });
            return;
        }
    }
}
