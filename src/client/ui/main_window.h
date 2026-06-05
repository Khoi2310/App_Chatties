#ifndef CHATTIES_MAIN_WINDOW_H
#define CHATTIES_MAIN_WINDOW_H

#include <QMainWindow>
#include <QLabel>
#include <QPushButton>
#include <QListWidget>

namespace chatties {
namespace client {

class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr);
    ~MainWindow();

private slots:
    void on_connect_clicked();
    void on_disconnect_clicked();
    void on_send_message_clicked();

private:
    void setup_ui();
    void create_menu();
    void create_toolbar();

    QLabel* status_label_;
    QPushButton* connect_btn_;
    QPushButton* disconnect_btn_;
    QPushButton* send_msg_btn_;
    QListWidget* message_list_;
};

} // namespace client
} // namespace chatties

#endif // CHATTIES_MAIN_WINDOW_H
