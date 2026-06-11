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

    // Hiển thị tin nhắn của mình lên danh sách
    ui->messageList->addItem("Tôi: " + text);

    // Gửi lên server (sender_id tạm để là 1)
    client_->sendMessage(1, 1, text);

    ui->inputField->clear();
}

void MainWindow::onMessageReceived(QString json) {
    // Parse JSON để lấy nội dung tin nhắn
    QJsonDocument doc = QJsonDocument::fromJson(json.toUtf8());
    QJsonObject obj   = doc.object();

    QString content  = obj["content"].toString();
    int senderId     = obj["sender_id"].toInt();

    ui->messageList->addItem(
        QString("User %1: %2").arg(senderId).arg(content)
        );
}

MainWindow::~MainWindow() {
    delete ui;
}