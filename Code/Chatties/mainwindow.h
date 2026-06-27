#pragma once
#include <QMainWindow>
#include <QJsonObject>
#include <QJsonArray>

QT_BEGIN_NAMESPACE
namespace Ui { class MainWindow; }
QT_END_NAMESPACE

class ChatClient;

class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    explicit MainWindow(QWidget* parent = nullptr);
    ~MainWindow();

private slots:
    void onSendClicked();
    void onLoginClicked();
    void onRegisterClicked();
    void onAuthOk(int userId, QString username, QString displayName);
    void onAuthError(QString reason);
    void onHistory(QJsonArray messages);
    void onMessage(QJsonObject message);

private:
    void appendMessage(const QJsonObject& msg);
    void setAuthenticated(bool authed);

    Ui::MainWindow* ui;
    ChatClient*     client_;
};
