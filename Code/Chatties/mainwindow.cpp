#include "mainwindow.h"
#include "ui_mainwindow.h"
#include "chatclient.h"
#include <QJsonObject>
#include <QJsonDocument>

MainWindow::MainWindow(QWidget* parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
    , client_(new ChatClient(this))
{
    ui->setupUi(this);
    setWindowTitle("Chatties");

    // Khi nhận tin nhắn → hiển thị lên danh sách
    connect(client_, &ChatClient::messageReceived,
            this,    &MainWindow::onMessageReceived);

    // Khi kết nối thành công → thông báo
    connect(client_, &ChatClient::connected, this, [this]() {
        ui->messageList->addItem("✅ Đã kết nối server!");
    });

    // Khi mất kết nối → thông báo
    connect(client_, &ChatClient::disconnected, this, [this]() {
        ui->messageList->addItem("❌ Mất kết nối server!");
    });

    // Nút Gửi
    connect(ui->sendButton, &QPushButton::clicked,
            this,           &MainWindow::onSendClicked);

    // Nhấn Enter trong ô nhập cũng gửi tin
    connect(ui->inputField, &QLineEdit::returnPressed,
            this,           &MainWindow::onSendClicked);

    // Kết nối đến server
    client_->connectToServer("127.0.0.1", 8080);
}

void MainWindow::onSendClicked() {
    QString text = ui->inputField->text().trimmed();
    if (text.isEmpty()) return;

    QString username = ui->usernameField->text().trimmed();
    if (username.isEmpty()) username = "Ẩn danh";

    // Hiển thị tin nhắn của mình lên danh sách
    ui->messageList->addItem("Tôi: " + text);

    // Gửi lên server (channel_id tạm để là 1)
    client_->sendMessage(1, username, text);

    ui->inputField->clear();
}

void MainWindow::onMessageReceived(QString json) {
    // Parse JSON để lấy nội dung tin nhắn
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QJsonObject obj   = doc.object();

    QString content  = obj["content"].toString();
    QString username = obj["username"].toString();
    if (username.isEmpty())
        username = QString("User %1").arg(obj["sender_id"].toInt());

    ui->messageList->addItem(username + ": " + content);
}

MainWindow::~MainWindow() {
    delete ui;
}