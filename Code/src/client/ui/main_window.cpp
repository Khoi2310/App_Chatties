#include "main_window.h"
#include "../../common/utils/logger.h"
#include "../../common/constants.h"
#include "../../common/protocol/packet_definitions.h"
#include "../network/socket_client.h"
#include <QVBoxLayout>
#include <QHBoxLayout>
#include <QMenuBar>
#include <QToolBar>
#include <QStatusBar>
#include <QMessageBox>
#include <QInputDialog>
#include <QJsonObject>
#include <QJsonDocument>
#include <QThread>
#include <QTimer>

namespace chatties {
namespace client {

MainWindow::MainWindow(QWidget* parent)
    : QMainWindow(parent)
    , socket_client_(nullptr)
    , receive_timer_(nullptr)
{
    utils::Logger::instance().initialize("client.log", utils::LogLevel::DEBUG);
    utils::Logger::instance().info("[MainWindow] Khởi tạo giao diện.");

    setup_ui();
    create_menu();
    create_toolbar();

    setWindowTitle("Chatties");
    resize(800, 600);
}

MainWindow::~MainWindow() {
    if (receive_timer_) {
        receive_timer_->stop();
    }
    if (socket_client_ && socket_client_->is_connected()) {
        socket_client_->disconnect();
    }
    utils::Logger::instance().info("[MainWindow] Đóng cửa sổ.");
}

void MainWindow::setup_ui() {
    // Widget trung tâm
    QWidget* central = new QWidget(this);
    setCentralWidget(central);

    QVBoxLayout* main_layout = new QVBoxLayout(central);
    main_layout->setSpacing(6);
    main_layout->setContentsMargins(10, 10, 10, 10);

    // Thanh trạng thái kết nối
    status_label_ = new QLabel("🔴 Chưa kết nối", this);
    status_label_->setStyleSheet("font-weight: bold; color: red;");
    main_layout->addWidget(status_label_);

    // Danh sách tin nhắn
    message_list_ = new QListWidget(this);
    message_list_->setStyleSheet(
        "QListWidget { background-color: #2C2F33; color: #FFFFFF; border-radius: 4px; }"
        "QListWidget::item { padding: 4px; border-bottom: 1px solid #40444B; }"
    );
    main_layout->addWidget(message_list_, 1);

    // Hàng nhập tin nhắn
    QHBoxLayout* input_layout = new QHBoxLayout();

    input_field_ = new QLineEdit(this);
    input_field_->setPlaceholderText("Nhập tin nhắn...");
    input_field_->setStyleSheet(
        "QLineEdit { background-color: #40444B; color: white;"
        "border-radius: 4px; padding: 6px; }"
    );
    input_field_->setEnabled(false); // Chỉ bật khi đã kết nối
    input_layout->addWidget(input_field_, 1);

    send_msg_btn_ = new QPushButton("Gửi", this);
    send_msg_btn_->setStyleSheet(
        "QPushButton { background-color: #7289DA; color: white;"
        "border-radius: 4px; padding: 6px 16px; }"
        "QPushButton:hover { background-color: #5B6EAE; }"
        "QPushButton:disabled { background-color: #4E5058; }"
    );
    send_msg_btn_->setEnabled(false);
    input_layout->addWidget(send_msg_btn_);

    main_layout->addLayout(input_layout);

    // Hàng nút kết nối
    QHBoxLayout* conn_layout = new QHBoxLayout();

    connect_btn_ = new QPushButton("🔌 Kết nối", this);
    connect_btn_->setStyleSheet(
        "QPushButton { background-color: #43B581; color: white;"
        "border-radius: 4px; padding: 6px 16px; }"
        "QPushButton:hover { background-color: #3CA374; }"
    );
    conn_layout->addWidget(connect_btn_);

    disconnect_btn_ = new QPushButton("❌ Ngắt kết nối", this);
    disconnect_btn_->setStyleSheet(
        "QPushButton { background-color: #F04747; color: white;"
        "border-radius: 4px; padding: 6px 16px; }"
        "QPushButton:hover { background-color: #D03E3E; }"
        "QPushButton:disabled { background-color: #4E5058; }"
    );
    disconnect_btn_->setEnabled(false);
    conn_layout->addWidget(disconnect_btn_);

    conn_layout->addStretch();
    main_layout->addLayout(conn_layout);

    // Kết nối signal/slot
    connect(connect_btn_,    &QPushButton::clicked,
            this,            &MainWindow::on_connect_clicked);
    connect(disconnect_btn_, &QPushButton::clicked,
            this,            &MainWindow::on_disconnect_clicked);
    connect(send_msg_btn_,   &QPushButton::clicked,
            this,            &MainWindow::on_send_message_clicked);
    connect(input_field_,    &QLineEdit::returnPressed,
            this,            &MainWindow::on_send_message_clicked);

    // Thanh trạng thái dưới cùng
    statusBar()->showMessage("Sẵn sàng");
}

void MainWindow::create_menu() {
    QMenu* file_menu = menuBar()->addMenu("&File");
    file_menu->addAction("Thoát", this, &QWidget::close);

    QMenu* help_menu = menuBar()->addMenu("&Help");
    help_menu->addAction("Về Chatties", this, [this]() {
        QMessageBox::about(this, "Chatties",
            "Ứng dụng chat Discord-like\nPhiên bản 0.1");
    });
}

void MainWindow::create_toolbar() {
    QToolBar* toolbar = addToolBar("Main Toolbar");
    toolbar->setMovable(false);
    toolbar->addAction("🔌 Kết nối",   this, &MainWindow::on_connect_clicked);
    toolbar->addAction("❌ Ngắt",      this, &MainWindow::on_disconnect_clicked);
    toolbar->addSeparator();
    toolbar->addAction("🗑️ Xóa chat", this, [this]() {
        message_list_->clear();
    });
}

void MainWindow::on_connect_clicked() {
    // Hỏi server host (mặc định localhost)
    bool ok;
    QString host = QInputDialog::getText(
        this, "Kết nối Server",
        "Địa chỉ Server:",
        QLineEdit::Normal,
        "127.0.0.1", &ok
    );
    if (!ok || host.isEmpty()) return;

    // Tạo SocketClient và kết nối
    socket_client_ = std::make_unique<SocketClient>(
        host.toStdString(),
        chatties::SERVER_PORT
    );

    if (socket_client_->connect()) {
        // Cập nhật UI
        status_label_->setText("🟢 Đã kết nối: " + host);
        status_label_->setStyleSheet("font-weight: bold; color: green;");
        statusBar()->showMessage("Kết nối thành công!");

        connect_btn_->setEnabled(false);
        disconnect_btn_->setEnabled(true);
        send_msg_btn_->setEnabled(true);
        input_field_->setEnabled(true);
        input_field_->setFocus();

        message_list_->addItem("✅ Đã kết nối đến " + host);

        // Bắt đầu nhận tin nhắn mỗi 100ms
        receive_timer_ = new QTimer(this);
        connect(receive_timer_, &QTimer::timeout,
                this,           &MainWindow::on_receive_message);
        receive_timer_->start(100);

    } else {
        QMessageBox::critical(this, "Lỗi",
            "Không thể kết nối đến " + host + "\nKiểm tra Server đã chạy chưa?");
    }
}

void MainWindow::on_disconnect_clicked() {
    if (receive_timer_) {
        receive_timer_->stop();
        receive_timer_->deleteLater();
        receive_timer_ = nullptr;
    }

    if (socket_client_) {
        socket_client_->disconnect();
        socket_client_.reset();
    }

    status_label_->setText("🔴 Chưa kết nối");
    status_label_->setStyleSheet("font-weight: bold; color: red;");
    statusBar()->showMessage("Đã ngắt kết nối.");

    connect_btn_->setEnabled(true);
    disconnect_btn_->setEnabled(false);
    send_msg_btn_->setEnabled(false);
    input_field_->setEnabled(false);

    message_list_->addItem("❌ Đã ngắt kết nối.");
}

void MainWindow::on_send_message_clicked() {
    if (!socket_client_ || !socket_client_->is_connected()) return;

    QString text = input_field_->text().trimmed();
    if (text.isEmpty()) return;

    // Đóng gói JSON theo đúng MessagePacket
    QJsonObject obj;
    obj["type"]       = static_cast<int>(protocol::PacketType::MESSAGE_SEND);
    obj["channel_id"] = 1;
    obj["sender_id"]  = 1;    // TODO: dùng user_id thật sau khi login
    obj["content"]    = text;

    QJsonDocument doc(obj);
    std::string json = doc.toJson(QJsonDocument::Compact).toStdString();

    socket_client_->send_data(json);

    // Hiển thị tin nhắn của mình
    message_list_->addItem("Tôi: " + text);
    message_list_->scrollToBottom();
    input_field_->clear();
}

void MainWindow::on_receive_message() {
    if (!socket_client_ || !socket_client_->is_connected()) return;

    // Nhận dữ liệu từ server (non-blocking check)
    std::string data = socket_client_->receive_data();
    if (data.empty()) return;

    // Parse JSON
    QJsonDocument doc = QJsonDocument::fromJson(
        QByteArray::fromStdString(data)
    );
    if (doc.isNull()) {
        message_list_->addItem("[Raw] " + QString::fromStdString(data));
        return;
    }

    QJsonObject obj = doc.object();
    QString content   = obj["content"].toString();
    int     sender_id = obj["sender_id"].toInt();

    message_list_->addItem(
        QString("User %1: %2").arg(sender_id).arg(content)
    );
    message_list_->scrollToBottom();

    utils::Logger::instance().info(
        "[MainWindow] Nhận tin từ user " +
        std::to_string(sender_id) + ": " + content.toStdString()
    );
}

} // namespace client
} // namespace chatties