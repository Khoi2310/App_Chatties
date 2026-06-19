#pragma once
#include <QAbstractListModel>
#include <QJsonObject>
#include <QJsonArray>
#include <QVector>

class MessageModel : public QAbstractListModel {
    Q_OBJECT

public:
    enum Roles {
        UsernameRole = Qt::UserRole + 1,
        ContentRole,
        TimestampRole,
        AuthorIdRole
    };

    explicit MessageModel(QObject* parent = nullptr);

    int rowCount(const QModelIndex& parent = QModelIndex()) const override;
    QVariant data(const QModelIndex& index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

public slots:
    void appendMessage(const QJsonObject& msg);
    void loadHistory(const QJsonArray& messages);
    void clear();

private:
    struct Item {
        QString username;
        QString content;
        qint64  timestamp = 0;
        int     authorId  = 0;
    };
    QVector<Item> items_;
};
