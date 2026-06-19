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
        case UsernameRole:  return it.username;
        case ContentRole:   return it.content;
        case TimestampRole: return it.timestamp;
        case AuthorIdRole:  return it.authorId;
        default:            return {};
    }
}

QHash<int, QByteArray> MessageModel::roleNames() const {
    return {
        { UsernameRole,  "username"  },
        { ContentRole,   "content"   },
        { TimestampRole, "timestamp" },
        { AuthorIdRole,  "authorId"  }
    };
}

void MessageModel::appendMessage(const QJsonObject& msg) {
    Item it;
    it.username  = msg.value("username").toString();
    it.content   = msg.value("content").toString();
    it.timestamp = static_cast<qint64>(msg.value("timestamp").toDouble());
    it.authorId  = msg.value("author_id").toInt();

    beginInsertRows(QModelIndex(), items_.size(), items_.size());
    items_.push_back(it);
    endInsertRows();
}

void MessageModel::loadHistory(const QJsonArray& messages) {
    beginResetModel();
    items_.clear();
    for (const auto& v : messages) {
        const QJsonObject o = v.toObject();
        Item it;
        it.username  = o.value("username").toString();
        it.content   = o.value("content").toString();
        it.timestamp = static_cast<qint64>(o.value("timestamp").toDouble());
        it.authorId  = o.value("author_id").toInt();
        items_.push_back(it);
    }
    endResetModel();
}

void MessageModel::clear() {
    beginResetModel();
    items_.clear();
    endResetModel();
}
