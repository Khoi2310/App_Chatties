#pragma once
#include <QObject>
#include <QTcpSocket>
#include <QString>

class ChatClient : public QObject {
    Q_OBJECT

public:
    explicit ChatClient(QObject* parent = nullptr);

    // Kết nối đến server
    void connectToServer(const QString& host, quint16 port);

    // Gửi tin nhắn lên server
    void sendMessage(int channelId, const QString& username, const QString& content);

signals:
    void connected();                          // Khi kết nối thành công
    void disconnected();                       // Khi mất kết nối
    void messageReceived(QString jsonPayload); // Khi nhận tin nhắn mới

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();    // Khi có dữ liệu từ server

private:
    QTcpSocket* socket_;
};
