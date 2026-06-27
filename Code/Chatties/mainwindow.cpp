#include "mainwindow.h"
#include "ui_mainwindow.h"
#include "chatclient.h"

MainWindow::MainWindow(QWidget* parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
    , client_(new ChatClient(this))
{
    ui->setupUi(this);
    setWindowTitle("Chatties");

    // Tín hiệu kết nối
    connect(client_, &ChatClient::connected, this, [this]() {
        ui->statusLabel->setText("Đã kết nối. Hãy đăng nhập hoặc đăng ký.");
    });
    connect(client_, &ChatClient::disconnected, this, [this]() {
        ui->statusLabel->setText("❌ Mất kết nối server!");
        setAuthenticated(false);
    });

    // Tín hiệu xác thực / tin nhắn
    connect(client_, &ChatClient::authOk,          this, &MainWindow::onAuthOk);
    connect(client_, &ChatClient::authError,       this, &MainWindow::onAuthError);
    connect(client_, &ChatClient::historyReceived, this, &MainWindow::onHistory);
    connect(client_, &ChatClient::messageReceived, this, &MainWindow::onMessage);

    // Nút bấm
    connect(ui->loginButton,    &QPushButton::clicked, this, &MainWindow::onLoginClicked);
    connect(ui->registerButton, &QPushButton::clicked, this, &MainWindow::onRegisterClicked);
    connect(ui->sendButton,     &QPushButton::clicked, this, &MainWindow::onSendClicked);
    connect(ui->inputField,     &QLineEdit::returnPressed, this, &MainWindow::onSendClicked);

    setAuthenticated(false);
    client_->connectToServer("127.0.0.1", 8080);
}

MainWindow::~MainWindow() {
    delete ui;
}

void MainWindow::setAuthenticated(bool authed) {
    // Ẩn khu vực đăng nhập/đăng ký khi đã vào; bật composer.
    ui->authTabs->setVisible(!authed);
    ui->inputField->setEnabled(authed);
    ui->sendButton->setEnabled(authed);
}

void MainWindow::onLoginClicked() {
    client_->login(ui->loginUsernameField->text().trimmed(),
                   ui->loginPasswordField->text());
}

void MainWindow::onRegisterClicked() {
    const QString password = ui->regPasswordField->text();
    const QString confirm  = ui->regConfirmPasswordField->text();

    if (password != confirm) {
        ui->statusLabel->setText("⚠️ Mật khẩu xác nhận không khớp.");
        return;
    }

    client_->registerUser(ui->regUsernameField->text().trimmed(),
                          ui->regEmailField->text().trimmed(),
                          password,
                          ui->regDisplayNameField->text().trimmed());
}

void MainWindow::onAuthOk(int userId, QString username, QString displayName) {
    Q_UNUSED(userId);
    Q_UNUSED(username);
    ui->statusLabel->setText("✅ Đã đăng nhập: " + displayName);
    ui->messageList->clear();
    setAuthenticated(true);
}

void MainWindow::onAuthError(QString reason) {
    ui->statusLabel->setText("⚠️ " + reason);
}

void MainWindow::onHistory(QJsonArray messages) {
    for (const auto& v : messages) {
        appendMessage(v.toObject());
    }
}

void MainWindow::onMessage(QJsonObject message) {
    appendMessage(message);
}

void MainWindow::appendMessage(const QJsonObject& msg) {
    const QString username = msg["username"].toString();
    const QString content  = msg["content"].toString();
    ui->messageList->addItem(username + ": " + content);
}

void MainWindow::onSendClicked() {
    QString text = ui->inputField->text().trimmed();
    if (text.isEmpty()) return;

    // Server phát lại tin cho tất cả (kể cả mình), nên không tự hiển thị ở đây.
    client_->sendMessage(text);
    ui->inputField->clear();
}
