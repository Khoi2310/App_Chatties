#ifndef SOCKETSERVICE_H
#define SOCKETSERVICE_H

#include <QObject>
#include <QTcpSocket>
#include <QString>

class SocketService : public QObject {
    Q_OBJECT
public:
    explicit SocketService(QObject *parent = nullptr);
    
    void connectToHost(const QString &ip, quint16 port);
    void disconnectFromHost();
    void sendMessage(const QString &jsonStr);
    bool isConnected() const;

signals:
    void connectionSuccess();
    void connectionClosed();
    void messageReceived(const QString &message);
    void connectionError(const QString &errorMsg);

private slots:
    void onConnected();
    void onDisconnected();
    void onReadyRead();
    void onErrorOccurred(QAbstractSocket::SocketError socketError);

private:
    QTcpSocket *socket;
};

#endif // SOCKETSERVICE_H